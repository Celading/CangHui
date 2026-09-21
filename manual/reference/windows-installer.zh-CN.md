# Windows 安装包与便携包

[English](windows-installer.md)

仓绘提供薄打包入口，不要求全局安装 NSIS/WiX。带私有引擎的 CUIC 交付包可离线生成
Windows EXE；普通源码安装只带适配器，需要另选一个可信引擎包。构建机需要 Python 3.11+，
最终用户不需要 Python、CUIC 或 NSIS。应用自身的仓颉运行库和原生 DLL 仍需随 payload 带齐。

## 先准备能运行的应用目录

```text
my-app/
  canghui.toml
  payload/
    App.exe
    ...运行库、DLL、字体和应用资源
```

先验证 `payload/App.exe` 能在目标 Windows 机器运行，再打包。入口必须是 x86/x64 Windows
PE EXE，不能拿 macOS 文件、脚本或 DLL 改名替代。`canghui.toml` 的 `[application]`
提供 `name`、`identifier`、`version` 和可选 `publisher`。

```bash
# 当前用户安装版
cuic package installer windows . --payload payload --entry App.exe --output dist/setup

# 单文件便携版：不登记安装项、不申请管理员权限
cuic package installer windows . --payload payload --entry App.exe --mode portable --output dist/portable
```

输出目录必须不存在。生成目录包括 EXE、NSIS 脚本、NSIS 许可与 `receipt.json`。
回执分别记录编译、目标架构、文件摘要、签名和 Windows 运行验证；**编译成功不等于应用在目标机可用**。
当前入口不生成 MSI、不下载工具、不自动签名，不负责检查所有运行库依赖。

## 安装与卸载

默认使用 NSIS 原生确认和进度界面。应用安装到当前用户的
`LocalAppData/Programs/<identifier>/<version>`，建立开始菜单快捷方式与 HKCU 卸载项。
不提供任意安装路径或静默确认；`/S` 不绕过同意。相同版本目录已经存在时拒绝覆盖，先卸载旧版本
或改用应用自己的升级方案。失败可能留下部分安装目录，需要检查后处理，不声称事务回滚。

卸载只删除打包清单内文件和自己生成的卸载器、快捷方式、登记项；目录只做非递归清理。
未知文件会保留。请不要在安装目录保存用户数据，也不要把用户编辑文档放进 payload。
应用运行期间卸载遇到占用文件会报错，关闭应用后重试。

## 临时缓存与用户授权

默认缓存应存放在**操作系统提供的临时目录**内，结束后如果不再需要使用则自动删除缓存。
Unix 通常为系统 `/tmp` 或系统分配的临时根；Windows 使用系统 Temp，不硬编码 `/tmp`。
如需持久化缓存到用户文件目录，尽可能提醒用户获取相应授权，说明用途、位置和清理方式。

便携包使用 NSIS `InitPluginsDir` 创建的独占临时子目录，解包后 `ExecWait` 等待入口进程，
再由启动器退出清理。不会清空整个临时根、删除下载的源 EXE 或改写用户文档。
应用需要留存的设置/文件应使用自己的用户授权与存储接口，不写入这个临时 payload。

限制：崩溃、断电、文件占用可能留下残留；清理不是安全擦除。入口如果启动后台子进程后立刻退出，
`ExecWait` 不会自动等待全部后代。此类应用应保持前台宿主生命周期，或自行扩展进程管理，不能直接
宣称便携清理保证。命令行参数暂不转发给 payload，避免引入不透明的命令拼接。

## 私有引擎与扩展

默认从 CUIC 资源旁 `engines/canghui-package` 读取私有引擎，不从 PATH 猜测 `makensis` 或 `wix`。
HapCLI 负责外部工具发现/版本托管；也可显式选择已经取得的可信包：

```bash
cuic package installer windows . --payload payload --entry App.exe --output dist/setup \
  --engine-bundle /trusted/canghui-package
```

引擎需符合 [引擎包契约](../../tools/cuic/delivery/README.md)，包含宿主编译器、匹配的模板/插件、
许可和逐文件 SHA-256。摘要检查发现损坏或替换，不证明供应者身份；先信任来源，再接入。
普通 Git 源码不携带原生工具二进制。发布者可用 `delivery/bundle.py` 将审核后的引擎和 CUIC
组合成自包含工具目录；宿主运行库、签名和各平台实测仍是独立发布要求。

私有引擎名为 **canghui-package**，底层使用并保留 NSIS 许可。
`--honor-system` 启用 `chui-honor-v1`：成对替换归档头的四个格式标识及读取端，隐藏标准
NSIS 归档签名，使只认标准头的解包器不能直接按 NSIS 格式打开。引擎缺少配对版本时拒绝构建，
不静默退化成普通包。标准 PE/MZ 加载头、CRC 与上游许可不变；生成后再签名。
这是真正的格式混淆彩蛋，**不是加密或不可解包保证**：适配过的工具、调试与运行时临时文件仍可恢复内容。
回执将 `headerObfuscation` 与 `extractionProtection=false` 分开表达；不要在客户端保存秘密。

更精细的自绘安装 UI、企业 MSI、更新/回滚、服务安装、下载器和自删启动器由应用自己的交付系统扩展。
可以复用输出清单与 NSIS 脚本，但修改后需重新编译、签名与验收，旧回执不能代表新包。
自绘 UI 只做前端，权限、文件事务与安装状态仍交给专门后端，避免把仓绘 UI 内核变成安装管理器。
