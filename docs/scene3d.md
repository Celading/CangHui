# Scene3D 语义投影

CangHui Multiplatform 通过 `chui.scene3d` 提供 provider-neutral 的 3D 场景合同。
应用交付不可变的场景快照；可选 provider 负责把快照投影到具体渲染后端。
应用代码无需引入 bgfx 句柄、shader 字节或原生窗口指针。

`import chui.*` 会重新导出本页使用的 Scene3D 公开类型。

## 语义实体

`Scene3DEntitySnapshot` 保留实体身份、位置、可见性和一个通用类别，并允许以零值
保持类别默认尺寸，或显式提供 `scaleX/Y/Z` 与 `rotationX/Y/Z`。当前投影为八类实体
提供稳定的低多边形几何和颜色语义：

| `Scene3DEntityKind` | 几何家族 | 语义色角色 |
|---|---|---|
| `Floor` | `Slab` | `GroundNeutral` |
| `Route` | `Ribbon` | `RouteAccent` |
| `Vehicle` | `Box` | `VehicleAccent` |
| `UserMarker` | `Marker` | `UserHighlight` |
| `Structure` | `Box` | `StructureNeutral` |
| `Track` | `Ribbon` | `TrackNeutral` |
| `Facility` | `Marker` | `FacilityAccent` |
| `ExitMarker` | `Marker` | `ExitAccent` |

```cangjie
import chui.*

let camera = Scene3DCameraSnapshot(7.2, 5.4, 8.8, 0.0, -0.5, 0.0,
    fieldOfViewY: 48.0)
let frame = Scene3DFrameSnapshot("station-debug", camera: Some(camera))
frame.add(Scene3DEntitySnapshot(
    "floor",
    0.0,
    -0.35,
    0.0,
    kind: Scene3DEntityKind.Floor,
    scaleX: 4.8,
    scaleY: 0.10,
    scaleZ: 3.2
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
`entityId`、位置、尺寸、旋转和 `visible`。`Scene3DFrameSnapshot.camera` 是可选的；未提供
时 provider 保持原有默认相机。不指定 `kind`、相机或变换的旧构造调用仍按原有默认值
处理，因此原有消费者不需要为新增字段立即改写。

## Provider 边界

`Scene3DProvider` 按 attach / load / submit / present / detach 生命周期工作。快照在 submit
边界上封闭，provider 必须继续遵守 surface generation 和 frame ordering 检查。
`visible == false` 的实体保留在输入快照中，但不应提交可见几何。

框架仓内的 [`scene3d-bgfx`](../packages/scene3d-bgfx/README.md) 是一个可选实现，目前只提供
macOS arm64 Metal 的当前主机验证。普通 CangHui 构建和一般消费者不会因此下载、
编译或链接 bgfx 原生库。

## macOS 关闭生命周期

可选 `MacOSSdlMetalHost` 在 `pump()` 中排空 SDL event 队列。收到
`SDL_EVENT_QUIT` 后，`shouldClose()` 返回 `true`；消费者应结束自己的正常帧循环，
随后调用 provider `detach` 并关闭宿主。`shouldClose()` 只是关闭请求，不会替产品
决定路由状态、资源策略或退出文案。

```cangjie
while (!host.shouldClose()) {
    host.pump()
    let _ = provider.submit(frame, clock)
    let _ = provider.present(clock)
}
let _ = provider.detach(surface.id, surface.generation)
host.close()
```

确定性捕获可以按固定帧数退出，但一次捕获成功不能替代正常窗口关闭路径的证明。
通用 provider 的 Metal 图也不能替代产品消费者证明：产品仍需拥有领域对象映射、
用户入口、fallback、生命周期和最终制品验收。

## 非目标

这一通用投影不是产品场景模型、材质系统或美术规范。它不包含模型/纹理导入、
文字标注、拾取、碰撞、导航算法、实时传输、嵌入式 Scene3D 视图或移动端渲染认证。
产品可以把自身领域对象投影为上述八类通用低多边形实体，但领域类型不应进入 CangHui
公开合同。
