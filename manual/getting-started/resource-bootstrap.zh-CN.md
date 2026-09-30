# 资源开箱引导

应用需要字体、符号、包内数据、图片或应用图标时，先走这一页。它把新建 `cuic` 工程、声明资源、首帧前注册和打包检查串成一条最小路径。

## 1. 先固定消费表面

在应用根目录记录 `cjpm.toml` 中的框架提交、`cjpm.lock` 中的解析结果和已安装命令版本：

```bash
cuic version
cuic doctor macos --project . --verbose
cuic build macos .
```

三者不一致时先停在消费端依赖修复。不要通过修改框架缓存来解决消费端版本漂移。

## 2. 声明逻辑资源

manifest 使用项目相对路径，运行时通过 `ApplicationResources` 解析。不要扫描当前工作目录，也不要自行猜测替代文件。

```cangjie
import chui.{ApplicationResourceDeclaration, ApplicationResourceRole,
    ApplicationResourceRoot, ApplicationResources}

func applicationResources(projectRoot: String): ApplicationResources {
    ApplicationResources([
        ApplicationResourceDeclaration(
            "body-font", "assets/fonts/Body-Regular.ttf",
            role: ApplicationResourceRole.TextFont, family: "Demo Sans"),
        ApplicationResourceDeclaration(
            "fallback-font", "assets/fonts/Body-Fallback.ttf",
            role: ApplicationResourceRole.FallbackFont, family: "Demo Fallback"),
        ApplicationResourceDeclaration(
            "symbols", "assets/symbols/catalog.json",
            role: ApplicationResourceRole.SymbolCatalog),
        ApplicationResourceDeclaration(
            "seed-data", "assets/data/seed.json",
            role: ApplicationResourceRole.Data)
    ], [ApplicationResourceRoot.source(projectRoot)])
}

func registerApplicationFonts(resources: ApplicationResources): Unit {
    resources.registerFonts()
}
```

在创建首个窗口前调用 `registerFonts()`。`TextFont`、`FallbackFont` 和 `SymbolFont` 是三个不同角色。不要把符号字体或图标字体放进中文文本回退；图标使用 `Icon`、`Symbol` 或声明的符号目录。

## 3. 按真实格式能力使用图片

通用图片和网络资源路径支持 PNG、BMP；本版本没有给通用 `ImageView` 承诺 SVG、JPEG 解码。SVG 只在部分符号或 Linux 应用图标路径中出现；macOS 应用图标使用 ICNS 或方形 PNG，Windows 使用 ICO。按目标路径预转换或声明资源，不要靠扩展名猜测能力。

## 4. 打包并查看资源图

```bash
cuic doctor macos --project . --verbose
cuic package plan macos .
cuic package build macos .
```

回执应能看到逻辑资源、包内相对源路径和最终目标。缺失文件、重复逻辑名、路径穿越、符号链接输入和过期移动端 generation 都必须失败。构建通过也不等于所有平台宿主都已运行验收。

## 5. macOS 应用图标

声明方形 PNG 或现成 ICNS：

```toml
[assets]
application-icon = "assets/app.png"
```

在 macOS 主机上，`cuic package build macos .` 会用 `sips` 和 `iconutil` 把合规方形 PNG 转成 `Contents/Resources/application.icns`。非 macOS 主机不能完成 PNG→ICNS；跨主机应提供 ICNS 或把构建放在 macOS。Finder 图标刷新、签名和公证是独立验收门。

## 6. 增量构建出现不同结果时

记录框架提交、`cjpm.lock`、`cuic version`、`cjpm --version`、目标文件摘要和首窗口启动顺序。clean 只用于对照，不是修复契约。若错误包含 `native UI owner`，检查首窗口前所有阻塞初始化是否位于 `DesktopThreadLease` 内，后台结果是否通过 `DesktopApp.postToUi` 回到 UI owner。
