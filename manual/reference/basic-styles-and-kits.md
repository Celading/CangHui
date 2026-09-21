# 基础样式与可选 Kit

只依赖 `chui` 就能做完整应用。基础样式提供中性的浅色、深色和控件状态；设计套件按需选择，
不是启动框架的前提，也不要求复制整个框架来改界面。

## 谁负责什么

| 层 | 保留内容 | 不负责 |
| --- | --- | --- |
| `chui` | Theme、基础控件、语义角色、焦点、输入/DPI、无障碍、动画、布局与资源生命周期 | 特定产品的欢迎页、品牌素材、完整设计系统 |
| `canghui_kit` | 密度、选择卡、设置行、步骤与 Editorial / Focused / Guided 构图 | 第二套输入、焦点或应用状态管理 |
| `canghui_style_liquid_glass` | 玻璃材料配方、光学参数和组件视觉策略 | 声称平台原生玻璃或所有后端效果相同 |
| 应用 | 数据、验证、导航、请求、持久化、品牌资产与业务动作 | 重写核心事件循环以换皮肤 |

通用裁剪、渐变、滤镜、属性动画仍属于核心与渲染提供者；玻璃配方使用这些能力。
不能因为一个效果用于某种风格，就把通用渲染能力一起迁走。现有包名、Theme、ButtonStyle、
ComponentTheme、Kit API 保留；已有应用不需要一次性迁移。

## 基础样式也是可交付样式

- 默认 Button 最小高度 38 vp，左右内容 padding 12 vp、最小宽度 72 vp；高容器不应自动撑高按钮。
- 触屏密度应显式选择至少 44 vp 的点击区域；Kit 的 Compact / Comfortable / Touch 分别为 32 / 38 / 44 vp。
  紧凑密度不是触屏可达性认证。标签变长时先换行/重排，不靠无界拉高按钮补救。
- 保留浅深主题、hover/press、可见键盘焦点与禁用态。忙碌操作使用应用状态、进度提示和
  `.enabled(false)` 阻止重复提交；Kit 不擅自启动请求。
- 错误必须有文字说明，不能只变红；主题中的 danger 是语义角色，不代替验证逻辑。
  基础浅色 danger 在默认页面背景上为 4.85:1；`scripts/test-basic-style-palette.py`
  检查浅深主题的 12 组不透明文字/背景角色。这不代表透明材质或任意自定义背景的像素认证。
- `Theme.withReduceMotion(true)` 与 Glass 的 `LiquidGlassPreferences` 使用已有动画开关。
  玻璃还应响应减少透明度、增强对比度。自定义颜色、透明叠底与图像背景必须重新验收对比度。

基础控件的尺寸、禁用命令回归见 `basic_style_contract_test.cj`；键盘焦点、press、quiet 样式继续由
现有 Button / InteractionSurface 测试承担，不创建另一个组件引擎。

## 两种消费方式

**正常源码依赖**：应用固定框架提交，只添加选中的包。两个包都只直接依赖 `chui`，不互相依赖，
当前都无额外资源和原生库。未选的 Kit 不进入此依赖闭包；核心自身的 SDL 等依赖仍存在。

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_kit = { path = "../CangHui/packages/kit" }
# 仅需要玻璃时，另选 ../CangHui/packages/style-liquid-glass
```

**选择性源码导入**：需要长期自改配方时，导出一个应用所有的副本。Python 3.11+，目标父目录须已存在，
输出目录须不存在且不在框架内：

```sh
python3 CangHui/scripts/export-kit-source.py --kit kit \
  --chui /path/to/CangHui --output /path/to/application/vendor/my-kit
```

玻璃包用 `--kit style-liquid-glass`。导出后在应用的 `cjpm.toml` 指向该目录；包名保持原名，
不要同时依赖原包和副本。仅修改副本里的配方，不复制核心焦点/输入/渲染实现。

导出包含源码、测试、README、许可证/归属、`OWNED-SOURCE.md` 与 `kit-source.json`。
后者记录版本、源提交、源脏状态、依赖与文件 SHA-256；它是可核对的来源记录，不是签名证书。
生成的 `chui` 路径是本机构建配置；跨机器交付应有意替换并再次构建。当前兼容声明是通用源码，
最低版本门槛不等于每个编译器或原生宿主均已验证。

升级始终导出到**新的候选目录**，以旧上游副本为基线做三方比较，再由应用合并修改。
工具拒绝覆盖已有目录，也拒绝新增但未审核的资源、依赖和符号链接源文件。发生磁盘错误可能留下
不完整目录，应检查后另选新目录重试；工具不会递归删除用户文件。不是自动 SDK 安装器。

## 验收换的是风格，不是行为

[Kit parity 示例](../../examples/kit-parity/README.md) 使用同一应用模型：选择本地库、验证、确认、返回。
基础纵向流程、Editorial 分栏和 Glass 浮层构图复用同一动作与焦点 ID。比较窄宽、浅深、减少动效、
布局与动作回放，再用 `cuic prnt` 看框架像素；不能只比较色板。

示例为对照刻意链接两个 Kit，不代表普通应用必须如此。无 Kit 消费仍可用
[learning-flow](../../examples/learning-flow/README.md)。通用语义回放、逻辑坐标缩放、macOS SDL 像素
和物理触屏/其他系统验收须分别记录；`cuic shell touch` 当前是逻辑 click 别名，不是硬件触屏证明。
