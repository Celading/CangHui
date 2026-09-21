# macOS 桌面线程归属

仓颉线程可以在原生线程之间迁移。SDL/AppKit 窗口的创建、事件轮询、绘制和销毁必须留在同一条
macOS 主线程；同一个函数或同一个仓颉线程并不能保证这一点。

`DesktopApp` 底层 `SdlRuntime` 自动持有线程租约，直到最后一次对应关闭；多个窗口的租约可以嵌套。
若创建窗口前还需要读取配置、等待后台任务或其他会挂起的初始化，在 `main` 最前面加入口租约：

```cangjie
import chui.*

main(): Unit {
    try (owner = DesktopThreadLease()) {
        // 配置读取、后台初始化及其结果等待均在租约之后。
        let app = DesktopApp(WindowSpec("Example", 640, 480))
        app.run { Label("Hello") }
    }
}
```

租约只固定当前仓颉线程；后台 `spawn` 仍可并发运行，结果用 `app.postToUi` 交回，不在后台操作窗口。
租约需由创建它的仓颉线程关闭，且在窗口销毁之后关闭；不可让租约或原生窗口逃出受控生命周期。
如果进入租约前已经迁离主线程，会在调用 SDL 前失败并给出提示，而不会把工作线程伪装成主线程。
不要在全局初始化中执行可能挂起的工作后才尝试恢复主线程，也不要以全局 `cjProcessorNum=1` 替代修复。

当前 macOS 适配使用 CJNative 内部 `CJ_BindOSThread/CJ_UnbindOSThread`，不是标准库公开稳定 API。
1.0.5/1.1.3 可用性按版本检查，真实 SDL 生命周期回归以 1.1.3 为准；升级运行时应重新运行
[native-thread-owner 示例](../../examples/native-thread-owner/README.md)。已有外部线程绑定不会被本库接管或解除。
Windows/Linux/Harmony 宿主不因本次 macOS 修复自动获得新的线程支持声明。

文件对话框、系统菜单等原生交互仍应在实际消费者中单独验收。框架测试成功不代表旧的物化依赖已更新。
