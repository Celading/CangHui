[chui](../../index.md) › chui.desktop

# chui.desktop

```cangjie
import chui.desktop.*
```

桌面应用对象包：[`DesktopApp`](DesktopApp.md) 拥有 SDL 窗口与渲染循环，驱动构建-布局-绘制-事件分发，并提供资源管理、系统文件对话框、基础光标与最小窗口尺寸等应用级设施。闲置帧被跳过（脏帧机制），[`DesktopCaptureRequest`](DesktopCaptureRequest.md) 提供稳定采集接口；旧 `--snapshot` 仅作兼容。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`DesktopApp`](DesktopApp.md) | 桌面应用对象：拥有 SDL 窗口并运行帧循环——每帧从 [`run`](DesktopApp.md#run) 的界面构建函数重建组件树、布局、分发输入、绘制。 |
| [`DesktopCaptureRequest`](DesktopCaptureRequest.md) | 宿主与框架之间的一次稳定渲染采集请求。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`FramePacing`](FramePacing.md) | 桌面渲染帧的设备同步、固定目标帧率或不封顶策略。 |

## 函数

| 函数 | 说明 |
|---|---|
| `framePacingName` | 返回 `device`、`fixed-<fps>fps` 或 `unbounded` 的稳定诊断名称。 |
