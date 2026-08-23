# Scene3D 语义投影

CangHui Multiplatform 通过 `chui.scene3d` 提供 provider-neutral 的 3D 场景合同。
应用交付不可变的场景快照；可选 provider 负责把快照投影到具体渲染后端。
应用代码无需引入 bgfx 句柄、shader 字节或原生窗口指针。

`import chui.*` 会重新导出本页使用的 Scene3D 公开类型。

## 语义实体

`Scene3DEntitySnapshot` 保留实体身份、位置、可见性和一个通用类别。当前调试投影
为四类实体提供稳定的几何和颜色语义：

| `Scene3DEntityKind` | 几何家族 | 语义色角色 |
|---|---|---|
| `Floor` | `Slab` | `GroundNeutral` |
| `Route` | `Ribbon` | `RouteAccent` |
| `Vehicle` | `Box` | `VehicleAccent` |
| `UserMarker` | `Marker` | `UserHighlight` |

```cangjie
import chui.*

let frame = Scene3DFrameSnapshot("station-debug")
frame.add(Scene3DEntitySnapshot(
    "floor",
    0.0,
    -0.35,
    0.0,
    kind: Scene3DEntityKind.Floor
))
frame.add(Scene3DEntitySnapshot(
    "route-main",
    0.0,
    -0.18,
    0.0,
    kind: Scene3DEntityKind.Route
))
frame.add(Scene3DEntitySnapshot(
    "vehicle-01",
    0.55,
    0.0,
    0.0,
    kind: Scene3DEntityKind.Vehicle
))
frame.add(Scene3DEntitySnapshot(
    "user",
    -0.65,
    0.0,
    0.0,
    kind: Scene3DEntityKind.UserMarker
))
frame.seal()
```

`projectScene3DEntity` 把单个快照转换为 `Scene3DDebugEntityProjection`，同时保留
`entityId`、位置和 `visible`。不指定 `kind` 的旧构造调用仍按 `Vehicle` 处理，
因此原有消费者不需要为新字段立即改写。

## Provider 边界

`Scene3DProvider` 按 attach / load / submit / present / detach 生命周期工作。快照在 submit
边界上封闭，provider 必须继续遵守 surface generation 和 frame ordering 检查。
`visible == false` 的实体保留在输入快照中，但不应提交可见几何。

框架仓内的 [`scene3d-bgfx`](../packages/scene3d-bgfx/README.md) 是一个可选实现，目前只提供
macOS arm64 Metal 的当前主机验证。普通 CangHui 构建和一般消费者不会因此下载、
编译或链接 bgfx 原生库。

## 非目标

这一通用投影不是产品场景模型、材质系统或美术规范。它不包含模型/纹理导入、
文字标注、拾取、碰撞、导航算法、实时传输或移动端渲染认证。产品可以把自身领域对象
投影为上述四类通用调试实体，但领域类型不应进入 CangHui 公开合同。
