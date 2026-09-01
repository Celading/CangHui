[chui](../../index.md) › [chui.core](index.md) › DesignSnapshotV2

# DesignSnapshotV2

`canghui.design-snapshot/v2` 是 [`DesignSnapshot`](DesignSnapshot.md) v1 的兼容扩展包络。
它完整嵌入一份 v1 hard-truth，并新增设计工具需要的公开组件/源码定位、声明式交互边和
Multiplatform 适配场景。v1 的 JSON 字节、摘要和 CUIC 默认行为均不改变。

## 组件与源码绑定

```cangjie
let source = DesignSourceBinding(
    "explorerx.ui",
    "FileToolbar",
    "src/ui/file_toolbar.cj",
    line: 28,
    column: 5,
    sourceDigest: "sha256:<64 lowercase hex>"
)

let binding = DesignComponentBinding(
    "toolbar.open",
    "IconButton",
    source,
    publicProperties: ["icon", "tooltip", "variant"],
    variants: ["quiet", "primary"],
    slots: ["icon"]
)
```

路径必须是项目相对路径。绝对路径、`..`、URL、Windows drive、换行和 NUL 会被拒绝。
SHA-256 由拥有源码/资源的调用方提供；CangHui 验证格式并携带完整性事实，不伪造摘要。

## 交互与函数跳转

```cangjie
let interaction = DesignInteractionBinding(
    "open.activate",
    "toolbar.open",
    DesignInteractionTrigger.Click,
    DesignInteractionTargetKind.Action,
    "file.open",
    handlerPackage: "explorerx.ui",
    handlerSymbol: "openSelectedFile",
    handlerRelativePath: "src/ui/file_toolbar.cj",
    shortcut: "CmdOrCtrl+O"
)
```

trigger 覆盖 click/double-click/long-press、hover、focus/blur、key、submit、value-change、
drag 和 gamepad activate。target 明确区分 action、route、state、component 与安全的外部
intent。handler 只是可跳转的公开符号身份；包络不保存 callback、脚本、坐标注入或可执行
代码，因此不会把设计检查面变成运行时控制隧道。

## CangHui 推荐跨端场景

`cangHuiRecommendedDesignScenes()` 返回六个通用验收目标：

- phone compact 3x；
- tablet medium 2x；
- desktop expanded 1x 与 2x；
- foldable medium 2x；
- two-in-one expanded 2x 与放大字体。

每个 `DesignAdaptiveScene` 同时给出 logical viewport、density/font scale、safe area、
touch/pointer/keyboard/gamepad 输入类别和推荐 target/gap/grid/navigation。它们是可回放的
设计/预览合同，不是对应平台已经真机运行的证明。设备方向改变应选择新场景并重排布局，
不应把完整界面纹理旋转 90°/180°。

## ComponentProbe 与 CUIC

把 typed metadata 放进 probe：

```cangjie
ComponentProbe(
    "explorer.files",
    width: 1440.0,
    height: 900.0,
    designBindings: [binding],
    designInteractions: [interaction],
    designScenes: cangHuiRecommendedDesignScenes()
).run("@cui-design-snapshot-v2") {
    // stable .probe(...) tree
}
```

通过 CUIC 导出：

```bash
cuic design snapshot . explorer.files --version 2
```

`--version 1` 或省略 `--version` 仍输出 v1。所有设计导出和 probe 执行继续受 CUIC debug
通道约束。

公开 JSON 约束见
[`canghui-design-snapshot-v2.schema.json`](../../../../contracts/canghui-design-snapshot-v2.schema.json)。
v2 schema 通过相对 `$ref` 复用 v1 schema，避免复制或悄然改变 v1 事实。

## 边界

- v2 是 provider-neutral 交换合同，不包含 HaomoNav/HaomoDesign 治理字段或私有能力矩阵；
- design scene 和 style profile 不代表跨平台逐像素相同，平台像素仍需分别由 `cuic prnt` 验收；
- 本版建立绑定、交互和 adaptation 底座；反向 change-plan、三方冲突与完整 motion/resource
  往返属于 CK-CANGHUI-095 后续切片，不能因 v2 包络存在而宣称已完成。
