# Install the idea-build-env skill.
# Usage: .\install.ps1   or   irm ... | iex
#Requires -Version 5.1

$SkillName = 'idea-build-env'
$RepoUrl = 'https://github.com/chrisis58/idea-build-env-resolver/archive/refs/heads/main.zip'

try {
    # ---------- Choose install target ----------
    Write-Host "Install idea-build-env skill:"
    Write-Host "  [L] Current project  (default)"
    Write-Host "  [G] Global            (~\.claude\skills\)"
    $choice = Read-Host "Choose (L/G)"

    if ($choice -eq 'G' -or $choice -eq 'g') {
        $TargetDir = Join-Path $env:USERPROFILE ".claude\skills\$SkillName"
        $InstallLabel = "global (~\.claude\skills\$SkillName)"
        $IsGlobal = $true
    } else {
        $Resolved = (Resolve-Path "." -ErrorAction Stop).Path
        $TargetDir = Join-Path $Resolved ".claude\skills\$SkillName"
        $InstallLabel = "project ($TargetDir)"
        $IsGlobal = $false
    }

    Write-Host "Installing to $InstallLabel..."

    # ---------- Download ----------
    $TempZip = Join-Path $env:TEMP "$SkillName.zip"
    $TempDir = Join-Path $env:TEMP "$SkillName-temp"

    Write-Host "Downloading..."
    Invoke-WebRequest -Uri $RepoUrl -OutFile $TempZip -UseBasicParsing

    # ---------- Extract ----------
    Write-Host "Extracting..."
    Expand-Archive -Path $TempZip -DestinationPath $TempDir -Force

    # ---------- Find the skill folder in the extracted archive ----------
    # GitHub archive wraps everything in repo-branch/, e.g. idea-build-env-main/
    $ArchiveRoot = Get-ChildItem $TempDir -Directory | Select-Object -First 1
    $SkillSource = Join-Path $ArchiveRoot.FullName "skills\$SkillName"

    if (-not (Test-Path $SkillSource)) {
        # Repo root might be the skill itself (no skills/ wrapper)
        $SkillSource = $ArchiveRoot.FullName
    }

    # ---------- Install ----------
    if (Test-Path $TargetDir) {
        Remove-Item $TargetDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $TargetDir -Parent) | Out-Null
    Copy-Item -Path $SkillSource -Destination $TargetDir -Recurse

    # ---------- Cleanup ----------
    Remove-Item $TempZip, $TempDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Done! Skill installed to $TargetDir"
    Write-Host "It will be auto-discovered by Claude Code on the next session."

    if (-not $IsGlobal) {
        Write-Host "Tip: commit the .claude/skills/$SkillName/ directory to your repo."
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
