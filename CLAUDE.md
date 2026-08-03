# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo contains a Claude Code skill: **idea-build-env** — resolves JDK and Maven paths from IntelliJ IDEA project configuration. The skill is invoked before Maven/Java build commands in IDEA projects, ensuring builds use the same JDK and Maven as the IDE itself.

## Repository structure

```
skills/idea-build-env/
├── SKILL.md          # Skill definition (entry point, auto-discovered)
└── scripts/
    └── resolve-env.ps1  # PowerShell 5.1+, reads IDEA XML config, outputs KEY=value
install.ps1           # Interactive installer (local / global)
README.md             # English documentation
README.zh.md          # 中文文档
```

`SKILL.md` is the entry point. Claude Code auto-discovers skills by scanning for `SKILL.md` files. Only `SKILL.md` is auto-loaded.

## Documentation

This project maintains documentation in two languages:

- [README.md](README.md) — English
- [README.zh.md](README.zh.md) — 中文

When making changes, **keep both files in sync**. Every change to README.md must be reflected in README.zh.md, and vice versa.

## Testing

Run the resolve script against any IDEA project (a directory containing `.idea/misc.xml`):

```powershell
pwsh -NoProfile -File skills/idea-build-env/scripts/resolve-env.ps1 <project-root>
```

The script outputs `KEY=value` lines to stdout on success, or an error message to stderr and exits non-zero on failure. Never fill in paths if the script fails.

To test the full skill flow (Step 0 → Step 2), spawn a sub-agent pointed at an IDEA project and have it follow `SKILL.md` end-to-end.

## Script architecture

`resolve-env.ps1` performs three independent resolutions:

1. **IDEA config discovery** — scans `%APPDATA%\JetBrains\IntelliJIdea*` and `IdeaIC*` directories (newest first) to find `jdk.table.xml`
2. **JDK resolution** — reads `project-jdk-name` from `.idea\misc.xml`, matches it in the aggregated `jdk.table.xml` entries, resolves `$USER_HOME$` and `$PROJECT_DIR$` macros
3. **Maven resolution** — reads `.idea\workspace.xml` for `customMavenHome` / `localRepository` / `userSettingsFile`, with fallback to bundled Maven (`plugins\maven\lib\maven3` inside the IDEA install directory), Maven wrapper (`mvnw.cmd`), or Toolbox-managed installations

The script is Windows-only (`#Requires -Version 5.1`). It uses no external dependencies beyond PowerShell and the .NET XML APIs (`Select-Xml`).

## Distribution

This repo is intended for GitHub distribution. Users install via the one-liner:

```powershell
irm https://raw.githubusercontent.com/chrisis58/idea-build-env-resolver/refs/heads/main/install.ps1 | iex
```

This downloads and runs `install.ps1`, which interactively prompts for local (current project) or global (`~\.claude\skills\`) install. No git clone, no nested `.git` issues.

See `SKILL.md` for the full skill instructions that are distributed with the skill.
