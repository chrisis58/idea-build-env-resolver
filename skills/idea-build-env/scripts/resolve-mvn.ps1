# Step 2: Parse Maven path
# 调用方式：resolve-mvn.ps1 <项目根目录>
param([Parameter(Mandatory=$true)][string]$ProjectRoot)

$ws = Join-Path $ProjectRoot ".idea\workspace.xml"

if (-not (Test-Path $ws)) {
    Write-Error "找不到 .idea\workspace.xml（解析路径: $ws）。请确认传入的项目根目录正确。"
    exit 1
}

# MavenImportPreferences 组件下，Maven home / 本地仓库 / User settings file 均嵌套在
# <option name="generalSettings"><MavenGeneralSettings> 子树内。用显式路径而非 // 后代轴，
# 避免误匹配同名 option。
$generalSettingsXPath = "//component[@name='MavenImportPreferences']//MavenGeneralSettings"
$customMvnHome = (Select-Xml -Path $ws -XPath "$generalSettingsXPath/option[@name='customMavenHome']/@value" -ErrorAction SilentlyContinue).Node.Value
$mvnRepo       = (Select-Xml -Path $ws -XPath "$generalSettingsXPath/option[@name='localRepository']/@value" -ErrorAction SilentlyContinue).Node.Value
$userSettings  = (Select-Xml -Path $ws -XPath "$generalSettingsXPath/option[@name='userSettingsFile']/@value" -ErrorAction SilentlyContinue).Node.Value

if ($customMvnHome) {
    $mvnHome = $customMvnHome
    $mvnSource = "自定义路径: $customMvnHome"
} else {
    # Find IDEA installation directory
    $ideaHome = & {
        $p = (Get-Process -Name "idea64" -ErrorAction SilentlyContinue | Select-Object -First 1).Path
        if ($p) { return $p | Split-Path -Parent | Split-Path -Parent }
        $homePathFiles = Resolve-Path "$env:APPDATA\JetBrains\IntelliJIdea*\idea.home.txt" -ErrorAction SilentlyContinue
        if ($homePathFiles) {
            $homePath = Get-Content $homePathFiles -ErrorAction SilentlyContinue
            if ($homePath -and (Test-Path $homePath)) { return $homePath }
        }
        foreach ($pattern in @("$env:ProgramFiles\JetBrains\IntelliJ IDEA *","$env:LOCALAPPDATA\Programs\JetBrains\IntelliJ IDEA *")) {
            $found = Get-ChildItem $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
        $toolboxRoot = "$env:LOCALAPPDATA\JetBrains\Toolbox\apps"
        if (Test-Path $toolboxRoot) {
            $found = Get-ChildItem $toolboxRoot -Recurse -Depth 3 -Filter "idea64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { return $found.Directory.Parent.FullName }
        }
        return $null
    }
    if (-not $ideaHome) { Write-Error "Cannot locate IDEA."; exit 1 }
    $mvnHome = "$ideaHome\plugins\maven\lib\maven3"
    $mvnSource = "IDEA 内嵌"
}

$mvnCmd = "$mvnHome\bin\mvn.cmd"

Write-Output "MAVEN_HOME=$mvnHome"
Write-Output "MAVEN_CMD=$mvnCmd"
Write-Output "MAVEN_REPO=$mvnRepo"
Write-Output "MAVEN_USER_SETTINGS=$userSettings"
Write-Output "MAVEN_SOURCE=$mvnSource"

# Verify mvn.cmd exists
if (Test-Path $mvnCmd) { Write-Output 'MAVEN_CMD_EXISTS=true' } else { Write-Output 'MAVEN_CMD_EXISTS=false' }
