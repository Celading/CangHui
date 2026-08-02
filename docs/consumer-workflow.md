# Lightweight Consumer Workflow

**English** | [中文](consumer-workflow.zh-CN.md)

CangHui applications can depend on the framework without keeping a sibling source checkout or copying the
framework into every project. The workflow has three independently versioned parts:

- `cuic`: an installable command built from `tools/cuic`;
- the application: a normal executable CJPM module;
- `cui`: a public Git dependency pinned by `commitId` and frozen by `cjpm.lock`.

## Install cuic

The installer performs a sparse Git fetch containing only `tools/cuic`, compiles the command, and installs it
under `$HOME/.cjpm/bin` by default:

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

Select a reviewed tag, branch, or commit when required:

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | \
  bash -s -- --ref <reviewed-branch-or-commit>
```

## Create And Run An Application

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic doctor macos
cuic build macos
cuic run macos
```

`cuic init` also creates `canghui.toml`. Its `[scripts]` table is automatically discovered, allowing a project
to replace host-specific wrapper files with named, shell-free lifecycle pipelines:

```bash
cuic check
cuic dev
cuic snapshot-ui
```

The pipeline steps remain normal `cuic` commands; platform selection still follows the current host unless a
step names a supported platform explicitly. Script discovery is static project metadata and remains available
before the application can build or initialize runtime state.

The generated dependency is shaped as follows:

```toml
[dependencies]
cui = { git = "https://github.com/Celading/CangHui.git", commitId = "<reviewed-commit>" }
```

The first build asks CJPM to resolve the dependency if necessary. CJPM stores Git source under its configured
user cache, normally `$HOME/.cjpm/git`, and writes the resolved commit to `cjpm.lock`. Later builds reuse that
cache. Commit `cjpm.lock` with the application; use `cjpm update` only when intentionally changing dependency
resolution.

On macOS, `cuic` copies the installed Homebrew SDL3 and SDL3_ttf libraries into the resolved CangHui cache before
compilation and supplies the matching runtime path and bundled HarmonyOS Sans path while the application runs.
Linux uses `pkg-config`; Windows uses the framework's declared DLL surface. Platform doctor output remains the
authority for incomplete adapters.

## Local Framework Development

Use an explicit path only when modifying CangHui itself or working offline with a prepared checkout:

```bash
cuic init HelloCangHuiDev --canghui-path ../CangHui
```

`CANGHUI_FRAMEWORK_ROOT` is also an explicit command-level override. The older `CANGUI_FRAMEWORK_ROOT` name is
retained for compatibility.

## Scope

Git consumption is not a central-package publication. The user cache contains one source checkout per resolved
commit, while application projects remain small and portable. Desktop host proof does not imply complete iOS,
HarmonyOS, Android, Windows, or Linux application packaging.
