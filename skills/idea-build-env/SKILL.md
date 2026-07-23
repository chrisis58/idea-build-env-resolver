---
name: idea-build-env
description: >
  Resolve JDK (java.exe / javac.exe and other JDK tools)
  and Maven (mvn.cmd) absolute paths from IntelliJ IDEA project and global
  configuration files. Use before any Maven or Java command.

---

从 IntelliJ IDEA 配置文件解析 JDK 和 Maven 的绝对路径。

## 步骤

### 0. 检查 IDEA 环境

```
root = 用户显式提供的目录            # /idea-build-env <path> 的参数，或上下文中明确的 IDEA 项目路径

if root 为空:                       # 自动定位：从最近一级向上，最多三级
    for dir in [cwd, cwd/.., cwd/../.., cwd/../../..]:
        if exists(dir/.idea): root = dir; break

if root and exists(root/.idea):
    项目根目录 = root               # 作为步骤 2 脚本的 <项目根目录> 参数
elif 手动调用 (/idea-build-env):
    报错终止："未找到 .idea 目录，请确认在 IntelliJ IDEA 项目中执行此技能，或通过参数提供正确的项目根目录。"
else:                               # 自动触发（如构建前自动解析）
    跳过此技能，继续其他方式解析 JDK 和 Maven
```

> 显式提供时直接用该目录、不向上查找；自动定位时最近一级命中即停，避免误匹配上层无关的 `.idea`。

### 1. 检查 MEMORY 缓存

若项目 MEMORY 中已有 `idea-build-env`，`Test-Path` 检查缓存的 `JAVA_EXE` 和 `MAVEN_CMD` 是否仍存在于磁盘：
- 均存在 → 直接使用缓存值，跳到**输出**
- 任一不存在 → 继续步骤2

> 信任缓存，失败时重解析。配置变更极罕见，构建失败时再重新解析并更新 MEMORY。

### 2. 解析 JDK 与 Maven 路径（缓存失效时执行）

> 两个脚本共用同一个项目根目录参数（含 `.idea` 的目录），不依赖 cwd、不读环境变量。路径用单引号包裹，反斜杠/空格安全。

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '<skill 目录>/scripts/resolve-jdk.ps1' '<项目根目录>'; & '<skill 目录>/scripts/resolve-mvn.ps1' '<项目根目录>'"
```

> **JDK**：从 `.idea\misc.xml` 的 `ProjectRootManager` 解析 `project-jdk-name`，再到 IDEA 全局 `jdk.table.xml` 查找对应 `homePath`。  
> **Maven**：从 `.idea\workspace.xml` 的 `MavenImportPreferences` → `generalSettings` → `MavenGeneralSettings` 子树解析 `customMavenHome`、`localRepository`、`userSettingsFile`。三者均为可选：未设 `customMavenHome` 时回退到 IDEA 内嵌 Maven。

### 3. 缓存到项目 MEMORY

解析成功后，将以下字段写入 `memory/idea-build-env.md`：

- JDK_NAME, JDK_HOME, JAVA_EXE
- MAVEN_HOME, MAVEN_CMD, MAVEN_REPO, MAVEN_USER_SETTINGS, MAVEN_SOURCE

在 `memory/MEMORY.md` 中添加索引行：`- [IDEA Build Env](idea-build-env.md) — JDK/Maven paths from IDEA config`

## 输出

```toml
[output]
JDK_NAME = "IDEA 项目配置的 JDK 名称"
JDK_HOME = "JDK 安装根目录"
JAVA_EXE = "java.exe 完整路径"
MAVEN_HOME = "Maven 安装根目录"
MAVEN_CMD = "mvn.cmd 完整路径"
MAVEN_REPO = "Maven 本地仓库路径（可能为空）"
MAVEN_USER_SETTINGS = "Maven User settings file 路径（可能为空）"
MAVEN_SOURCE = "Maven 来源（自定义路径或\"IDEA 内嵌\"）"
```

## 注意事项

- **mvn 命令**：只要 `MAVEN_USER_SETTINGS`、`MAVEN_REPO` 有值，就**必须**分别用 `-s`、`-Dmaven.repo.local` 显式指定。JDK 命令（java/javap 等）无此限制。
- **上下文控制**：部分命令输出可能极长，必要时进行上下文控制（如主动截断、委托子agent等）。

## 错误处理

- **必要参数（JAVA_EXE / MAVEN_CMD / JDK_HOME）解析失败**：脚本报错并列出可用选项，提示用户修正配置
- **其他非必要参数解析失败**：忽略错误，跳过该参数
- **构建失败且缓存可能过期**：重新执行步骤2完整解析，更新 MEMORY，重试构建
