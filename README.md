# idea-build-env

A [Claude Code](https://claude.ai/code) skill that resolves JDK and Maven paths from IntelliJ IDEA project configuration — so builds run with the same toolchain the IDE uses.

## Problem

IDEA stores the project JDK and Maven config in its own files (not `PATH` or `JAVA_HOME`). Running `mvn` from a terminal picks up whatever `PATH` points to, which may be a different JDK or Maven than the IDE. The build silently differs — and that's worse than a clear failure.

## What this skill does

When Claude Code detects an IDEA project, it:

1. Locates the project root by searching upward for `.idea/`
2. Reads the JDK name from `.idea/misc.xml` and resolves it to an absolute path from IDEA's global config
3. Reads Maven settings from `.idea/workspace.xml` (custom home, local repository, user settings)
4. Falls back to IDEA's bundled Maven or project Maven wrapper when no custom Maven is configured
5. Caches the resolved paths so subsequent builds skip re-resolution

## Requirements

- Windows
- PowerShell 5.1+
- IntelliJ IDEA (Ultimate or Community)

## Install

Copy the skill into your project:

```
your-project/
└── .claude/
    └── skills/
        └── idea-build-env/
            ├── SKILL.md
            └── scripts/
                └── resolve-env.ps1
```

Or clone directly into `.claude/skills/`:

```bash
git clone https://github.com/chrisis58/idea-build-env.git .claude/skills/idea-build-env
```

That's it — Claude Code auto-discovers the skill on the next session.

## How it works

The skill activates automatically before any Maven or Java build command. You can also invoke it manually:

```
/idea-build-env                              # auto-locate project
/idea-build-env C:\path\to\idea-project      # explicit path
```

The resolved paths are used like this:

```powershell
$env:JAVA_HOME='<JAVA_HOME>'; & '<MAVEN_CMD>' -s '<MAVEN_USER_SETTINGS>' "-Dmaven.repo.local=<MAVEN_REPO>" <goals>
```

All three (`JAVA_HOME`, `-s`, `-Dmaven.repo.local`) must be set whenever non-empty — `mvn.cmd` uses `JAVA_HOME` for its JDK and does not read IDEA's repository or settings config.
