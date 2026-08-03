# idea-build-env

一个 [Claude Code](https://claude.ai/code) 技能，从 IntelliJ IDEA 项目配置中解析 JDK 和 Maven 路径，确保构建使用与 IDE 相同的工具链。

## 解决的问题

IDEA 将项目的 JDK 和 Maven 配置存储在自己的文件中（而非 `PATH` 或 `JAVA_HOME`）。在终端直接运行 `mvn` 会使用 `PATH` 中指向的版本，可能与 IDE 不同。构建在静默中产生差异——这比明确的失败更危险。

## 功能

当 Claude Code 检测到 IDEA 项目时：

1. 向上搜索 `.idea/` 定位项目根目录
2. 从 `.idea/misc.xml` 读取 JDK 名称，在 IDEA 全局配置中解析为绝对路径
3. 从 `.idea/workspace.xml` 读取 Maven 设置（自定义路径、本地仓库、用户配置文件）
4. 未配置自定义 Maven 时回退到 IDEA 内嵌 Maven 或 Maven Wrapper
5. 缓存解析结果，后续构建跳过重复解析

## 环境要求

- Windows
- PowerShell 5.1+
- IntelliJ IDEA（Ultimate 或 Community 版均可）

## 安装

### 一行命令（推荐）

```powershell
irm https://raw.githubusercontent.com/chrisis58/idea-build-env-resolver/refs/heads/main/install.ps1 | iex
```

选择 `L` 安装到当前项目（默认，直接回车），或 `G` 安装到全局（所有项目生效）。

### 结果

```
your-project/
└── .claude/
    └── skills/
        └── idea-build-env/
            ├── SKILL.md
            └── scripts/
                └── resolve-env.ps1
```

## 使用方式

技能会在任何 Maven 或 Java 构建命令前自动激活。也可以手动调用：

```
/idea-build-env                              # 自动定位项目
/idea-build-env C:\path\to\idea-project      # 显式指定路径
```

解析结果的使用方式：

```powershell
$env:JAVA_HOME='<JAVA_HOME>'; & '<MAVEN_CMD>' -s '<MAVEN_USER_SETTINGS>' "-Dmaven.repo.local=<MAVEN_REPO>" <goals>
```

值非空时三者（`JAVA_HOME`、`-s`、`-Dmaven.repo.local`）必须同时指定——`mvn.cmd` 通过 `JAVA_HOME` 获取 JDK，不会自动读取 IDEA 的仓库和 settings 配置。
