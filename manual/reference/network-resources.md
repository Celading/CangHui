# 网络资源与自定义传输

仓绘推荐使用 **Ignite** 作为仓颉 HTTP 应用栈，但核心 `chui` 不依赖任何 Web 框架。
服务端不必使用 Ignite：返回标准HTTP资源即可。`NetworkResourceTransport`允许注入其他
HTTP客户端或平台原生接口。未注入适配器不会联网，`ImageView("https://...")`不是隐式加载器。

## 最短路径

1. 应用侧实现`NetworkResourceTransport.open`或传入`CallbackResourceTransport`回调。
   推荐起点：[Ignite适配示例](../samples/network-resource-ignite/ignite_transport.cj)。
2. 创建`NetworkResourceLoader(transport, cacheRoot, ["https://assets.example.org"])`。
   cacheRoot为已有、应用私有的可写目录；框架只删除自己创建的文件和子目录。
3. 在现有`UiTaskScope.submit`的prepare中下载，**不在UI draw/build中下载**。
4. apply运行于UI owner，更新State后声明`ImageView.fromNetworkResource(file)`。
5. 替换图片时关闭旧文件；页面退出时取消任务并关闭loader。

文件关闭与纹理释放属于两个生命周期。需要立即释放已上传纹理时，在UI owner先调用
`invalidateImage(file.path())`再`file.close()`；否则纹理由既有LRU或窗口关闭回收。
不要在绘制仍使用文件时从其他线程主动关闭它。

```cangjie
// 模型初始化；transport与cacheRoot由应用提供。
let loader = NetworkResourceLoader(transport, cacheRoot, ["https://assets.example.org"])
let image = State<?NetworkResourceFile>(None)
let errorText = State<String>("")
let control = NetworkResourceControl()
// scope在DesktopApp构建内用app.rememberTaskScope("hero")取得；事件回调启动下载。
let task = scope.submit({=>
    loader.fetchResult(NetworkResourceRequest("https://assets.example.org/hero.png",
        kind: NetworkResourceKind.Png), control: control)
}, {result =>
    match (result) {
        case NetworkResourceResult.Ready(file) => image.value = Some(file)
        case NetworkResourceResult.Failed(code) => errorText.value = code
    }
})
// 后续UI构建
match (image.value) {
    case Some(file) => ImageView.fromNetworkResource(file)
    case None => Label("尚未加载")
}
// 用户取消/退出时执行，不要紧接启动代码立即调用：
control.cancel()
let _ = task.cancel()
loader.close()
```

`fetchResult`让成功和失败都进入UI owner的apply，避免失败后界面一直停在加载中；
底层`fetch`是抛异常的工作线程接口。由UI owner显示错误与显式重试按钮，默认不自动重试。
被取消或丢弃的已完成结果仍归loader管理、计入预算，最终由close清理。
这是一套临时资源会话，不是持久HTTP缓存；不按URL共享用户认证资源。

## 默认预算

| 范围 | 默认 |
| --- | --- |
| 单响应实际字节 | 16 MiB |
| 会话保留文件及在途预留 | 64 MiB，在途先预留单响应上限 |
| 文件数 / 同时下载 | 16 / 4 |
| 流读取块 | 最大64 KiB，不调用whole-body API |
| 请求时限 | 15秒，允许1–300000ms |
| 协议与响应 | HTTPS、显式origin允许列表、仅200、不跟随重定向、identity编码 |

通过`NetworkResourceOptions`调整；本地测试/明确允许的内网可显式`allowHttp: true`。
URL仅接受规范化ASCII形式、小写域名（IDN预先punycode），拒绝URL凭据、fragment、
反斜线和控制字符。不把URL变成磁盘文件名，不将URL/令牌放入框架错误或设计快照。
传输实现自己的日志仍由应用负责脱敏。

没有Content-Length时也逐块限额；已声明过大、超长、截断、空体、压缩、状态错误均拒绝，
关闭响应并清理部分文件。PNG/BMP要求匹配媒体类型，但下载成功不代表图片解码成功：
绘制仍受[图片预算](image-memory.md)约束；畸形图片按既有规则不绘制。
Data只提供文件，不解压、不执行、不自动注册字体或加载动态库。

## 自定义适配器责任

- 流式读取，不能先把全部body转成String/Array。
- 校验证书和主机名；禁自动跳转、重试、解压，限制响应头。
- 设置连接/读写超时，在取消检查点检查control；支持时中止底层请求。
- closeHandler关闭响应及该请求创建的客户端；认证通过显式headers传递。

框架用单调时钟在open/read前后检查时限，但不能强杀任意阻塞的第三方函数。
示例配置stdx读写超时；DNS/连接及时取消仍受底层实现约束，不承诺硬实时总截止。
origin检查不等于DNS/IP固定或服务端SSRF防火墙；不可信输入仍需应用制定DNS重绑定、内网及代理策略。

ApplicationResources继续处理包内资源，不被网络fallback替换。
网络资源是产品能力，不是CUIC调试通道；没有listener、脚本执行或远程输入事件入口。
核心只含契约/预算，网络客户端位于可选适配层；Harmony权限与原生传输由宿主负责。
当前不含网络适配SDK发布、离线缓存、ETag、断点续传或GIF/HDR解码。
