# 图片内存与帧池

`ImageView(path)` 默认使用渲染器所属的有界图片缓存。普通应用不用持有纹理，
窗口关闭时缓存先释放，再销毁原生渲染器；不同窗口不再相互清空缓存。

## 默认预算

| 项目 | 默认值 | 口径 |
| --- | --- | --- |
| 图片像素 | 16,777,216 | 宽 × 高；4K UHD 在范围内，8K UHD 默认拒绝 |
| 输入文件 | 64 MiB | 压缩文件长度，不代表展开内存 |
| 单次解码工作量 | 320 MiB | `像素 × 16 + 文件长度` 的保守准入估算 |
| 纹理缓存 | 128 MiB / renderer | RGBA8 `宽 × 高 × 4` 逻辑估算 |
| 缓存条目 | 256 / renderer | 包含失败记录；可设 1–4096 |

当前路径是同步 PNG/BMP 解码。先从同一文件流读取有限的头部，检查尺寸、乘法、
文件长度及工作量，再交给 SDL 解码；不先读完整文件到托管数组。未知长度、不支持的
BMP DIB 和超预算文件会被拒绝。支持 BMP CORE、40/52/56/108/124 字节 DIB，
包含合法的负高度（top-down）；其他变体不自动绕过预算。

缓存装入前按最近使用顺序淘汰。单张图片超过缓存预算时不解码、不缓存纹理。
`ImageView` 失败时保持不绘图，并记入失败计数；`Surface.load` / `Renderer.loadTexture`
则抛出 `CuiException`。预算错误消息以 `image-budget:` 开头。缺失、损坏和超预算
路径的失败记录也有条目上限；被淘汰后可重试，保留期间须显式 `invalidateImage(path)`。

## 应用配置与诊断

```cangjie
import chui.*

// UI owner 线程，窗口启动前或帧之间执行；更新配置会清空已有成功/失败缓存。
configureImageMemory(ImageMemoryOptions(
    maxPixels: 16777216,
    maxEncodedBytes: 32 * 1024 * 1024,
    maxWorkingBytes: 256 * 1024 * 1024,
    cacheBytes: 64 * 1024 * 1024,
    cacheEntries: 128
))

let snapshot = FramePoolMemorySnapshot()
println(snapshot.managedHeapLimitBytes)
println(snapshot.managedAllocatedBytes)
println(snapshot.images.textureBytes)
println(snapshot.images.budgetRejections)

// 由宿主内存压力/后台事件决定调用；不读取或修改全局 GC 环境。
trimImageMemory(16 * 1024 * 1024)
// 或彻底释放图片缓存：clearImageCache()
```

`currentImageMemoryOptions()` 返回配置，`imageMemoryStats()` 返回活跃缓存的
renderers、entries、textureBytes、hits、misses、evictions、failures、budgetRejections。
窗口关闭后该窗口计数不再参与汇总，不是整个进程的历史累计。
`trimImageMemory` 是一次性回收，不改变后续准入上限；需要持续降额时重新配置。

这些操作和缓存使用都只能在共同的 UI/renderer owner 线程上执行，不能从后台任务
直接关闭纹理。低层 `Renderer.cachedImage` 返回借用纹理：不要保存到应用状态，
不要自行关闭；下一次缓存变更、淘汰或窗口关闭后不可再用。

## 上传与 GC 的边界

RGBA8 Array 上传在参数校验后调用 `acquireArrayRawData`，只借用到同步
`SDL_UpdateTexture` 返回，并在 `finally` 中释放。取消了显式原生 malloc 和逐字节副本，
但运行时自身可能为 acquisition 复制数据，不能称为所有平台绝对零拷贝。
原生指针入口仍要求调用者保证缓冲区大小、布局和调用期间存活。

`managedHeapLimitBytes` 和 `managedAllocatedBytes` 是运行时托管堆读数；纹理字段
只是逻辑估算。不能相加宣称进程 RSS、实际 GPU 占用或瞬时峰值，更不能把原生内存
直接等同于 GC 堆。需要增加运行时启动堆时，应使用对应仓颉版本支持的启动配置，
在进程启动前设置；不要在 `main` 中更改环境变量后声称堆上限已生效。

## 不包含的能力

- 不提供 GIF 动画/HDR 解码、自动缩图或所有格式的安全解析器。
- 不限制应用自行创建的 Array、Surface、Texture，或其他 SVG/文字/视频/帧图缓存。
- 工作量估算不是原生解码器分配器硬上限；图片应在读取期间保持稳定，攻击者并发
  改写同一文件不属于此预算接口的安全隔离保证。
- 每 renderer 预算不是多窗口全局上限；多窗口应用应据窗口数设置预算。
- 不自动侦测系统压力、不自动改 GC，不代表插帧或完整设备自适应帧池已实现。
- 本机原生回归不代替 Windows、HarmonyOS 或具体消费产品的内存验收。
