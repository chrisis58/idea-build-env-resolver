---
name: idea-build-env
description: >
  Resolve JDK and Maven paths from IntelliJ IDEA project configuration.
  Use before any Maven/Java build command in an IDEA project.

---

## Steps

### 0. Check IDEA environment

```
root = explicitly provided directory   # argument of /idea-build-env <path>, or a clear IDEA project path in context

if root matches "rebuild" | "force":
    rebuild_mode = true; root = ""     # keyword → auto-locate, skip cache

if root is empty:                       # auto-locate: search upward, up to three levels
    for dir in [cwd, cwd/.., cwd/../.., cwd/../../..]:
        if exists(dir/.idea/misc.xml): root = dir; break

if root and exists(root/.idea/misc.xml):
    if exists(root/build.gradle*) and not exists(root/pom.xml):
        stop — this is a Gradle project; this skill does not apply
    project root = root                 # used as the <project-root> argument in Step 2
elif manual invocation (/idea-build-env):
    error: ".idea directory not found. Ensure you are in an IntelliJ IDEA project, or provide the correct project root via argument."
else:                                   # auto-triggered (e.g. pre-build resolution)
    skip this skill, fall back to other ways of resolving JDK and Maven
```

> When checking for `.idea` use `.idea/misc.xml` (a file) — Glob does not match dot-prefixed directories.

### 1. Check MEMORY cache

When `rebuild_mode` is set, skip the cache and go directly to Step 2.

Reuse the `idea-build-env` memory entry only if **all** of the following hold:

1. Cached `PROJECT_ROOT` equals the `root` determined in Step 0.
2. `Test-Path` succeeds for `JAVA_EXE` and `MAVEN_CMD`.
3. `RESOLVED_AT` is newer than the last-write time of `.idea\misc.xml` and, if present, `.idea\workspace.xml`.

### 2. Resolve JDK and Maven paths (when cache is invalid)

Run the script with the project root. Do not rely on cwd or environment variables. Quote paths with single quotes.

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '<skill dir>/scripts/resolve-env.ps1' '<project root>'"
```

The script prints the output block (see **Output**) to stdout and nothing else, exiting non-zero on stderr if a required value fails. **Report exactly what the script printed; never guess or fill in a plausible-looking path.**

### 3. Cache to MEMORY

After successful resolution, write all fields from **Output** to your memory directory.

> NEVER write it inside the project's working tree or VCS.

## Output

```toml
[output]
PROJECT_ROOT        = <absolute project path>
RESOLVED_AT         = <ISO 8601 timestamp>
JDK_NAME            = <JDK name from IDEA>
JAVA_HOME           = <JDK home directory>
JAVA_EXE            = <path to java.exe>
MAVEN_HOME          = <Maven home; empty for wrapper>
MAVEN_CMD           = <path to mvn.cmd or mvnw.cmd>
MAVEN_REPO          = <local repository path; may be empty>
MAVEN_USER_SETTINGS = <settings.xml path; may be empty>
MAVEN_SOURCE        = custom | bundled | wrapper
```

## Using the values

`mvn.cmd` takes its JDK from `JAVA_HOME` and ignores `JAVA_EXE`, and it does not read IDEA's repository or settings config — omitting these silently builds with a different JDK and resolves against a different repository than the IDE. Set all three whenever the values are non-empty:

```powershell
$env:JAVA_HOME='<JAVA_HOME>'; & '<MAVEN_CMD>' -s '<MAVEN_USER_SETTINGS>' "-Dmaven.repo.local=<MAVEN_REPO>" clean install
```

Quote the whole `-D` token, not just the value. JDK tools need no flags — call them by absolute path: `& '<JAVA_EXE>' -version`. Maven output can be very long; truncate or delegate to a sub-agent.

## Error handling

- Required value (`JAVA_EXE`, `MAVEN_CMD`, `JAVA_HOME`) unresolved → stop, show the error and the available options (e.g. the JDK names in `jdk.table.xml`), ask the user.
- **Never fall back to `mvn`/`java` on PATH.** A build that succeeds with the wrong toolchain is worse than a clear failure.
- Optional value unresolved → leave empty, omit its flag.
- Build fails and the cache may be stale → re-run Step 2, update the cache, retry once.
