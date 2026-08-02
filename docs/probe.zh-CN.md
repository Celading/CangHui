# CangHui Probe 协议

[English](probe.md) | **中文**

`cui.probe.v0` 是 CangHui 的确定性、无设备插桩协议。它不创建 SDL 窗口，即可验证函数调用、组件结构、事件路由、动画采样和渲染命令形态。字体外观、裁切、平台集成与最终视觉检查仍应使用像素输出。

## 函数 Probe

导入 probe 宏，并标注一个顶层 `(String) -> String` 函数：

```cangjie
import cui.*
import cui.kmode.macros.*

@CuiProbe["settings.reset-preview"]
func resetPreview(payload: String): String {
    // 解析应用定义的有界输入，并返回稳定结果。
    "{\"ok\":true}"
}
```

Probe 名称由点分段组成。每一段以字母开头，后续可以包含字母、数字、`-`、`_`。生成符号会让同一编译作用域中的重复名称在编译期失败。运行时注册表拒绝已加载包之间的重复名称，`cuic probe diff` 会在执行前递归检查本地路径依赖，并报告所有重复位置。

注解不会暴露任意函数、shell 命令或文件系统访问。只有显式标注的字符串输入/字符串输出函数会进入注册表。

## 组件 Probe

使用 `ProbeNode` 或 `.probe(...)` 修饰器发布稳定的组件事实。`probedAction` 在保留原动作的同时记录回调激活：

```cangjie
@CuiProbe["gallery.primary-button"]
func primaryButtonProbe(script: String): String {
    let clicks = State<Int64>(0)
    ComponentProbe("gallery.primary-button", width: 320.0, height: 120.0).run(script) {
        Button("Run", probedAction("primary-button.click", { => clicks.value += 1 }))
            .key("primary-button")
            .probe(
                "primary-button",
                "Button",
                [ProbeProperty("label", "Run")],
                { => [ProbeProperty("clicks", clicks.value.toString())] }
            )
    }
}
```

默认报告只包含确定性的公开事实：

- 稳定节点 id、类型、父节点、子项顺序、属性与语义状态；
- 测量与布局矩形；
- 调用方提供的焦点、悬停、按下、禁用与选中状态；
- 路由事件、消费结果与回调激活；
- 动画 id、动效等级、时长、曲线、逻辑时间、进度与目标；
- scope、裁切、变换、绘制、文本和 Symbol 的 Draw IR。

报告不会输出对象地址、墙钟时间戳或本地路径。

## 事件脚本

脚本每行一个命令。空行和以 `#` 开头的行会被忽略。

```text
move-in 80 35
press 80 35
advance 60
release 80 35
assert activation primary-button.click 1
assert state primary-button selected true
assert draw text 1
```

支持的命令：

| 命令 | 用途 |
|---|---|
| `move-in x y`、`move-out x y`、`move x y`、`hover x y` | 在逻辑坐标发送指针移动。 |
| `press x y`、`release x y` | 发送主指针按钮。 |
| `key name` | 发送支持的按键，例如 `Enter`、`Space`、`Tab` 或方向键。 |
| `focus id` | 把确定性键盘焦点移动到稳定 id。 |
| `text value` | 发送文本输入。 |
| `advance ms` | 推进逻辑动画时间并发送帧事件。 |
| `draw` | 不改变逻辑时间，再捕获一帧。 |

支持的断言：

```text
assert node <id>
assert state <id> <name> <true|false>
assert property <id> <name> <value>
assert activation <name> <count>
assert event <command-prefix> consumed <true|false>
assert animation <node> <kind> active
assert animation <node> <kind> between <minimum> <maximum>
assert draw <kind> <minimum-count>
```

断言失败会保留在 JSON 报告中，并使 `cuic probe run` 返回非零状态。

## CLI

```bash
./tools/cuic/bin/cuic probe diff component-gallery
./tools/cuic/bin/cuic probe list component-gallery --json
./tools/cuic/bin/cuic probe describe component-gallery gallery.primary-button --json
./tools/cuic/bin/cuic probe run component-gallery gallery.primary-button \
  --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
  --json
```

需要提交事件脚本时，使用 `--script path/to/events.txt`。稳定报告契约见 [`contracts/cui-probe-v0.schema.json`](../contracts/cui-probe-v0.schema.json)。
