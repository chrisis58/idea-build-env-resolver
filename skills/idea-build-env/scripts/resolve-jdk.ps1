# Step 1: Parse JDK path
# 调用方式：resolve-jdk.ps1 <项目根目录>
param([Parameter(Mandatory=$true)][string]$ProjectRoot)

$misc = Join-Path $ProjectRoot ".idea\misc.xml"

if (-not (Test-Path $misc)) {
    Write-Error "找不到 .idea\misc.xml（解析路径: $misc）。请确认传入的项目根目录正确。"
    exit 1
}

$jdkName = (Select-Xml -Path $misc -XPath "//component[@name='ProjectRootManager']/@project-jdk-name").Node.Value
Write-Output "JDK_NAME=$jdkName"

# Find IDEA config directory
$ideaConfigDir = Get-ChildItem "$env:APPDATA\JetBrains\IntelliJIdea*" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$ideaConfig = "$($ideaConfigDir.FullName)\options\jdk.table.xml"
Write-Output "IDEA_CONFIG=$ideaConfig"

# Parse JDK home from jdk.table.xml
$jdkNode = (Select-Xml -Path $ideaConfig -XPath "//jdk[name/@value='$jdkName']/homePath/@value" -ErrorAction SilentlyContinue).Node
if (-not $jdkNode) {
    $allJdks = Select-Xml -Path $ideaConfig -XPath "//jdk" | ForEach-Object {
        $name = $_.Node.SelectSingleNode('name/@value').Value
        $home = $_.Node.SelectSingleNode('homePath/@value').Value -replace '\$USER_HOME\$', $env:USERPROFILE
        "$name -> $home"
    }
    Write-Error "JDK '$jdkName' not found. Available: $($allJdks -join '; ')"
    exit 1
}
$jdkHome = $jdkNode.Value -replace '\$USER_HOME\$', $env:USERPROFILE
$javaExe = "$jdkHome\bin\java.exe"
Write-Output "JDK_HOME=$jdkHome"
Write-Output "JAVA_EXE=$javaExe"

# Verify java.exe exists
if (Test-Path $javaExe) { Write-Output 'JAVA_EXE_EXISTS=true' } else { Write-Output 'JAVA_EXE_EXISTS=false' }
