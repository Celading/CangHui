# Harmony provider SDK 接入

CangHui 应用无需复制或修改框架源码。应用源码由 `cuic prepare harmony` 做确定性投影；
原生 provider 以一个带版本契约的目录交给 CUIC：

```bash
cuic prepare harmony . --provider /path/to/CangHUI --json
```

provider 根目录必须包含 `canghui-harmony-provider.env`。当前契约要求：

```text
schema=canghui.harmony-provider/v1
frameworkVersion=0.18.0
frameworkCommit=<40 位公开提交>
frameworkAbi=canghui.harmony-native-surface/v1
inputAbi=canghui.harmony-pointer/v2
projectionProtocol=canghui.harmony-projection/v1
targetAbi=arm64-v8a
artifacts=<以 provider 根为基准的逗号分隔文件>
```

CUIC 会在写生成目录之前拒绝版本、ABI、投影协议、目标 ABI、符号链接、路径逃逸、
缺失文件和重复路径。通过后，原生库、CMake linkage、公开头文件、许可证、provider
manifest、框架契约、ArkTS host 模板、C header、Cangjie 投影源和资源进入同一个保留
provider 相对结构、带 `inputDigest/outputDigest` 的生成树。
相同输入可无写入重放；框架、provider 或生成树漂移都会拒绝覆盖。

这条路径闭合的是“应用不 fork CangHui 即可取得确定性 Harmony 构建输入”。产品仍拥有
bundle identity、权限、ArkTS 页面、签名与 HAP 组装；公开 provider pack 也不等同于
该产品已通过安装、启动、输入、生命周期和真机像素验收。
