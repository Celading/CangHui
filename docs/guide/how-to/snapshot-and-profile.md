<!-- kind: how-to; audience: component-author -->

# 生成快照并定位帧耗时

## 目标

生成可检查的 BMP 快照，并把视觉回归与交互测试、帧性能记录分开。完成约需 15 分钟。

## 适用场景

组件文档示例、布局回归、主题变更和发布前烟雾检查。快照只能证明一个静态画面，不足以证明焦点、Modal、拖动或后台任务正确。

## 准备工作

准备固定窗口大小、稳定输入和可写的产物目录，记录构建类型、操作系统和字体环境。先决定哪些结果由快照自动检查，哪些由事件测试检查，哪些必须人工操作；三类状态在报告中分开，不能用一个“通过”概括。

## 操作步骤

### 1. 让初始画面确定

固定窗口尺寸、内置文本和本地资源；不要把当前时间、随机数或网络结果放进基准图。下面程序可普通交互运行，也可用 `--snapshot` 自动退出。

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("快照基准", 520, 320))
    app.run {
        let progress = rememberState<Float32>("release-progress") {0.72}
        VStack(spacing: 12.vp) {
            Label("发布检查").bold()
            ProgressBar(progress)
            HStack(spacing: 8.vp) {
                Badge("构建通过", kind: BadgeKind.Success)
                Label("72%").muted()
            }.height(36.vp)
            Button("主要动作", {=> ()}, role: ButtonRole.Primary)
        }.padding(24.vp)
    }
}
```

### 2. 运行快照模式

构建完成后执行：

```text
cjpm run --run-args="--snapshot artifacts/release-check.bmp"
```

进程应自动退出。检查文件存在、长度非零、BMP 头有效，并人工查看标题、进度条、徽章和按钮没有裁切。不要把“能构建”写成“已运行”；二者是不同证据。

### 3. 为交互另写测试

```cangjie role=variation
// 快照覆盖初始画面；事件测试覆盖行为。
let consumed = widget.handle(ctx, UiEvent.KeyDown(Key.Enter, KeyModifiers()))
@Expect(consumed)
@Expect(model.submitted.value)
```

Modal 背景屏蔽、Tab 顺序、菜单 Escape、画布拖动都应通过控件事件测试或人工步骤验证。快照可作为补充，不能替代这些断言。

### 4. 读取阶段帧报告

先分别测“静止 5 秒”“滚动大列表”“动画期间”“图片首次出现”和“图片缓存命中”。记录窗口大小、数据规模、构建类型与机器环境，再比较构建、布局、绘制各阶段；没有这些上下文的单个毫秒数不可复现。

## 确认结果

快照命令退出码为 0，BMP 可打开且尺寸与窗口一致。重复运行两次，稳定区域应一致。静止页面没有持续帧；动画或轮询结束后帧循环停下。交互清单独立记录为通过、失败或人工边界，不与快照结果混成一个“运行通过”。

## 常见错误

- 使用变化数据做黄金图：每次构建都产生噪声差异。
- 只检查文件存在：零字节或错误尺寸也会被误判通过。
- 把快照通过当成键盘可用：静态图看不出事件消费。
- 没有预热就比较纹理首次解码与缓存命中：数据不可比。

## 相关 API

[DesktopApp](../../api/cui/desktop/DesktopApp.md)、[ProgressBar](../../api/cui/controls/ProgressBar.md)、[Badge](../../api/cui/controls/Badge.md)。

## 下一步

一般启动、状态或浮层问题先看[通用排障](../troubleshooting/common-problems.md)；发现卡顿时到[媒体与性能排障](../troubleshooting/media-performance.md)，准备交付时继续[打包桌面应用](package-desktop-app.md)。
