# Resolve JDK and Maven paths from IntelliJ IDEA project and global configuration.
# Usage: resolve-env.ps1 <project-root>
# Output: KEY=value lines to stdout; non-zero exit + stderr message on failure.
#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$ProjectRoot)

$ErrorActionPreference = 'Stop'

function Fail([string]$msg) { Write-Error $msg; exit 1 }

# IDEA stores paths with forward slashes in XML and uses macros like $USER_HOME$.
# Resolve both so the returned path is usable on disk.
function Expand-IdeaMacro([string]$p) {
    if (-not $p) { return '' }
    $p = $p -replace '\$USER_HOME\$', $env:USERPROFILE
    $p = $p -replace '\$PROJECT_DIR\$', $script:Root
    return ($p -replace '/', '\')
}

if (-not (Test-Path $ProjectRoot)) { Fail "Project root not found: $ProjectRoot" }
$script:Root = (Resolve-Path $ProjectRoot).Path

# ---------- IDEA config directories (newest first; also matches IdeaIC / Community) ----------
$jbRoot = "$env:APPDATA\JetBrains"
$configDirs = @()
if (Test-Path $jbRoot) {
    $configDirs = Get-ChildItem $jbRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(IntelliJIdea|IdeaIC)\d{4}\.\d+$' } |
        Sort-Object @{ Expression = { [version]($_.Name -replace '^(IntelliJIdea|IdeaIC)', '') } } -Descending
}

# ---------- JDK ----------
$misc = Join-Path $Root '.idea\misc.xml'
if (-not (Test-Path $misc)) { Fail "Cannot find .idea\misc.xml (resolved: $misc). Is this an IntelliJ IDEA project?" }

$jdkNameNode = (Select-Xml -Path $misc -XPath "//component[@name='ProjectRootManager']/@project-jdk-name").Node
if (-not $jdkNameNode) { Fail 'No project-jdk-name set in misc.xml. The project has no SDK configured.' }
$jdkName = $jdkNameNode.Value

# Collect JDK entries from every installed IDEA version, not just the newest.
$jdks = @()
foreach ($d in $configDirs) {
    $table = Join-Path $d.FullName 'options\jdk.table.xml'
    if (-not (Test-Path $table)) { continue }
    foreach ($n in (Select-Xml -Path $table -XPath '//jdk').Node) {
        $nm = $n.SelectSingleNode('name/@value')
        $hp = $n.SelectSingleNode('homePath/@value')
        if ($nm) {
            $jdks += [pscustomobject]@{
                Name = $nm.Value
                Home = $(if ($hp) { Expand-IdeaMacro $hp.Value } else { '' })
            }
        }
    }
}
if (-not $jdks) { Fail "No jdk.table.xml found in any IDEA config under $jbRoot." }

# Match by name; prefer one whose home path actually exists on disk.
$cands = @($jdks | Where-Object { $_.Name -eq $jdkName })
$match = $cands | Where-Object { $_.Home -and (Test-Path $_.Home) } | Select-Object -First 1
if (-not $match) { $match = $cands | Select-Object -First 1 }
if (-not $match) {
    $all = ($jdks | ForEach-Object { "$($_.Name) -> $($_.Home)" }) -join '; '
    Fail "JDK '$jdkName' not found in jdk.table.xml. Available entries: $all"
}

$jdkHome = $match.Home
$javaExe = Join-Path $jdkHome 'bin\java.exe'

# ---------- Maven ----------
$ws = Join-Path $Root '.idea\workspace.xml'
$customMvnHome = ''; $mvnRepo = ''; $userSettings = ''; $homeType = ''
if (Test-Path $ws) {
    # Use explicit path, not // descendant axis, to avoid matching same-named options
    # under unrelated components.
    $gs = "//component[@name='MavenImportPreferences']/option[@name='generalSettings']/MavenGeneralSettings"
    $get = { param($n) (Select-Xml -Path $ws -XPath "$gs/option[@name='$n']/@value" -ErrorAction SilentlyContinue).Node.Value }
    $customMvnHome = Expand-IdeaMacro (& $get 'customMavenHome')
    $mvnRepo       = Expand-IdeaMacro (& $get 'localRepository')
    $userSettings  = Expand-IdeaMacro (& $get 'userSettingsFile')
    $homeType      = (& $get 'mavenHomeTypeForPersistence')
}
# workspace.xml is often gitignored — missing is normal, fall back to bundled Maven.

# customMavenHome may store a label like "Wrapper" / "Bundled (Maven 3)" rather than a
# real path. Treating it as a path would produce a non-existent mvn binary.
$marker = "$customMvnHome $homeType"
$mvnwCmd = Join-Path $Root 'mvnw.cmd'

if ($marker -match '(?i)wrapper') {
    $mvnSource = 'wrapper'
} elseif ($marker -match '(?i)bundled') {
    $mvnSource = 'bundled'
} elseif ($customMvnHome) {
    $mvnSource = 'custom'
} elseif (Test-Path $mvnwCmd) {
    $mvnSource = 'wrapper'          # no Maven configured but project ships a wrapper — match CI
} else {
    $mvnSource = 'bundled'
}

$mvnHome = ''
switch ($mvnSource) {
    'wrapper' {
        if (-not (Test-Path $mvnwCmd)) { Fail "Maven wrapper configured but $mvnwCmd missing." }
        $mvnCmd = $mvnwCmd
    }
    'custom' { $mvnHome = $customMvnHome; $mvnCmd = Join-Path $mvnHome 'bin\mvn.cmd' }
    'bundled' {
        $ideaHome = & {
            $p = (Get-Process -Name 'idea64' -ErrorAction SilentlyContinue | Select-Object -First 1).Path
            if ($p) { return (Split-Path (Split-Path $p -Parent) -Parent) }
            foreach ($pat in @("$env:ProgramFiles\JetBrains\IntelliJ IDEA *",
                               "$env:LOCALAPPDATA\Programs\JetBrains\IntelliJ IDEA *")) {
                $f = Get-ChildItem $pat -Directory -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending | Select-Object -First 1
                if ($f) { return $f.FullName }
            }
            $tb = "$env:LOCALAPPDATA\JetBrains\Toolbox\apps"
            if (Test-Path $tb) {
                $f = Get-ChildItem $tb -Recurse -Depth 5 -Filter 'idea64.exe' -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($f) { return $f.Directory.Parent.FullName }
            }
            return $null
        }
        if (-not $ideaHome) { Fail 'Bundled Maven requires IDEA install directory, but it could not be located. Configure a custom Maven home in IDEA settings.' }
        $mvnHome = Join-Path $ideaHome 'plugins\maven\lib\maven3'
        $mvnCmd  = Join-Path $mvnHome 'bin\mvn.cmd'
    }
}

# ---------- output ----------
Write-Output "PROJECT_ROOT=$Root"
Write-Output "RESOLVED_AT=$((Get-Date).ToString('s'))"
Write-Output "JDK_NAME=$jdkName"
Write-Output "JAVA_HOME=$jdkHome"
Write-Output "JAVA_EXE=$javaExe"
Write-Output "MAVEN_HOME=$mvnHome"
Write-Output "MAVEN_CMD=$mvnCmd"
Write-Output "MAVEN_REPO=$mvnRepo"
Write-Output "MAVEN_USER_SETTINGS=$userSettings"
Write-Output "MAVEN_SOURCE=$mvnSource"

# ---------- final sanity check ----------
$missing = @()
if (-not (Test-Path $javaExe)) { $missing += "java.exe not found: $javaExe" }
if (-not (Test-Path $mvnCmd))  { $missing += "mvn.cmd not found: $mvnCmd" }
if ($missing) { Fail ($missing -join '; ') }
