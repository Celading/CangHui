# 应用资源运行时

ApplicationResources 把 canghui.toml 已声明、由 cuic package/prepare staging 的资源映射为运行时逻辑名称。应用请求逻辑名，不遍历相对根猜文件。

```cangjie
let resources = ApplicationResources([
    ApplicationResourceDeclaration("body-font", "assets/fonts/body.ttf",
        role: ApplicationResourceRole.TextFont, family: "Demo Sans"),
    ApplicationResourceDeclaration("symbols", "assets/symbols/catalog.json",
        role: ApplicationResourceRole.SymbolCatalog),
    ApplicationResourceDeclaration("license", "LICENSE",
        role: ApplicationResourceRole.License)
], [
    ApplicationResourceRoot.macBundle(bundleRoot),
    ApplicationResourceRoot.source(projectRoot)
])

resources.registerFonts()
let catalog = resources.resolve("symbols")
```

根按调用方给出的顺序解析，并在回执中保留 source、macos-bundle、windows-package、linux-package 或 mobile-rawfile provenance。未声明名称、遍历、符号链接、缺失文件、重复逻辑名和过期移动端 generation 都会失败关闭。

source 根直接对应项目；macOS、Windows、Linux helper 与 cuic package 的资源布局一一对应；Harmony 生成目录使用 ApplicationResourceRoot.mobileRawfile，由当前宿主 generation 注入。字体注册只处理 TextFont、FallbackFont、SymbolFont；符号目录的解析和业务子集仍由应用决定。

## 路径与文件边界

声明路径统一使用 `/` 分隔，例如 `assets/fonts/body.ttf`；不要传入盘符、UNC 路径、
反斜线、空路径段、`.`、`..`、控制字符或带 `:` 的备用数据流名称。
主机注入的根路径则使用本机格式，可以包含空格和中文。

解析先取得实际规范路径，再检查完整目录边界。Windows 比较兼容两种分隔符，
不把路径转成小写，不把 Unicode 名称折叠成另一名称；因此不会将大小写敏感目录
中的同名变体当成同一个根。回执保留文件系统返回的原始规范路径。

资源根必须是非符号链接目录，声明目标必须是普通文件；声明路径中的符号链接
也会被拒绝。缺失目标可继续尝试后续根，越界、链接或类型错误不会静默回退。
全部根均缺失目标时明确报错，不自动寻找替代字体或文件。

这是应用包资源解析器，不是针对恶意并发文件替换的文件系统沙箱。解析返回的是
路径而非已锁定的文件句柄，调用方须保证资源目录不被不可信进程修改。
Windows junction、UNC 共享和大小写敏感目录仍需在目标系统上验收；其他平台的
单元测试不能替代 Windows 原生字体注册与安装包验证。
