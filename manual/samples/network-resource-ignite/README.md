# 可替换的网络资源适配示例

`ignite_transport.cj`是应用侧参考源码，不是已发布的网络SDK包。
使用Ignite 0.8.x的RequestBuilder/ClientResponse，通过显式配置底层stdx Client关闭自动
重定向、代理，使用单槽请求私有客户端并随响应关闭，限制头部、禁重试，并直接传递bodyStream。无需修改仓绘核心。
服务端可以是Ignite或其他Web框架，协议不带专有依赖。

在自己的CJPM应用中引入配对的chui、Ignite和stdx，将该文件放入src并改成应用包名。
依赖版本由应用锁定；不要将本机SDK路径提交进公开项目。示意：

```toml
[dependencies]
chui = { path = "../CangHui" }
ignite = { path = "../Ignite" }

[target.aarch64-apple-darwin.bin-dependencies]
path-option = ["${CANGJIE_STDX_PATH}/cj_stdx_darwin_aarch64_llvm/static/stdx"]
```

本地1.1.3静态stdx配置还需要链接`-lcangjie-dynamicLoader-opensslFFI`；按实际平台/SDK配置，
不是在chui核心增加此依赖。避免同一package内使用`import chui.*`引入多个None枚举候选，优先显式导入。

```cangjie
let loader = NetworkResourceLoader(IgniteResourceTransport(), cacheRoot,
    ["https://assets.example.org"])
```

生产应用保留HTTPS证书和主机名校验。示例设置读写超时，但底层DNS/连接取消不等于硬实时
总截止；框架只在返回控制权时检查累计时限。自定义传输应实现相同安全约束，不先全量缓冲。

## 本地重放

`python3 fixture.py`启动临时loopback服务，打印随机端口；Ctrl-C关闭。
将打印的origin显式加入允许列表，仅这个测试使用`allowHttp: true`。

- `/image`：真实2×2 PNG，下载后交给ImageView的原生解码/上传。
- `/large`：Content-Length超过4096测试预算，应在读取body前拒绝。
- `/chunked-large`：无Content-Length，实际流超过预算，应拒绝并清理。
- `/redirect`：必须拒绝，不能请求`/must-not-visit`。
- `/gzip`：必须拒绝编码不符。
- `/truncated`：必须失败，不能把部分文件交给UI。

夹具只属于本地测试，不由CangHui/CUIC启动，不参与应用发布；它不构成框架远程控制入口。
