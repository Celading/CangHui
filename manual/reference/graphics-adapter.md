# 跨后端 Graphics 适配

`chui.graphics` 是 CangHui Multiplatform 的 GPU 中立边界。应用描述需要的能力、资源与
绘制意图，平台 provider 再选择 Metal、Vulkan、D3D、OpenGL ES、WebGPU 或软件实现。
后端名称只出现在 provider 的能力与诊断结果里，不应写进业务状态或 Scene3D 模型。

`import chui.*` 会重新导出本页涉及的公开类型。

## 先协商能力

应用使用 `GraphicsAdapterRequest` 提交档位、能力、最低限额与电源偏好；
`GraphicsAdapter` 返回 `GraphicsAdapterSelection`。`Core3D` 是保守的可移植渲染档位，
`Compute3D` 额外要求 compute pipeline 与 storage buffer，`NativeExtended` 则明确接受
平台扩展。`allowFallback` 只允许 provider 返回可见的 `Degraded`，不会把缺失能力伪装成
完整支持。

```cangjie
let request = GraphicsAdapterRequest(
    GraphicsProfile.Core3D,
    powerPreference: GraphicsPowerPreference.HighPerformance,
    requiredCapabilities: [GraphicsCapability.Instancing],
    allowFallback: false
)
let selection = adapter.select(request, surfaceLease)
if (!selection.ok()) {
    throw IllegalStateException(selection.code)
}
```

`GraphicsSurfaceLease` 由宿主创建，包含逻辑/像素尺寸、缩放、颜色空间、透明模式与严格
递增的 generation。`platformToken` 是 provider 私有解析的 opaque token；应用不得把原生
窗口或 GPU handle 塞入场景数据、日志或跨进程协议。

## 再提交保留式 Render Packet

`GraphicsRenderPacket` 携带一组 `GraphicsSceneDelta`。资源与 render item 都使用
`slot + generation` 身份：同一 slot 复用时必须增加 generation，release 后的旧引用不能
重新生效。resource payload、delta 数量与整包字节数都有硬上限。

包可以通过 `packGraphicsRenderPacket` 生成确定性字节；解包和 `NullGraphicsReplay`
会先完整验证，再原子提交。悬空 binding、重复身份、旧 generation、释放仍被引用的资源
或部分失败都不会污染已提交状态。这一 fake replay 证明协议和状态机，不证明 GPU 像素。

## 与 Scene3D 的关系

`Scene3DFrameSnapshot` 是更高层的语义输入；Scene3D provider 可以把模型、材质与相机
翻译为 graphics resources/render items，再交给具体 adapter。应用通常不需要直接构造
render packet，除非正在实现新的渲染层或平台 provider。

当前仓库已经证明公共合同、确定性 replay、macOS arm64 的可选 bgfx4cj/Metal 路径与
HarmonyOS XComponent 宿主入口。它没有据此声称 Vulkan、D3D、OpenGL ES 或 WebGPU
provider 已经完整交付；每个后端仍需独立的编译、像素、生命周期、输入与发布回执。
