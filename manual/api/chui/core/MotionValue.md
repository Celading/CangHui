[chui.core](index.md) › MotionValue

# MotionValue

保留、可中断的单个 `Float32` 动效轨道，通过 `import chui.*` 使用。
在活动组件中用 `rememberState` 保存它，或由应用模型持有；不要每帧重新创建。

```cangjie
public init(value: Float32)
public prop value: Float32 { get }
public func settled(): Bool
public func reset(value: Float32): Unit
public func animate(ctx: UiContext, target!: Float32,
    spec!: AnimationSpec = AnimationSpec.automatic()): Float32
```

同一 `ctx.frame.elapsedMs` 只推进一次，可在测量和绘制中重复读取。
每段保留启动时的 AnimationSpec；更换 spec 在下次目标改变时生效。
新目标从已显示数值接续；初次调用和静止后的第一帧不会把空闲时间算入新段。
`reset` 取消当前段。停止采样或移除组件便不会继续请求帧；重新挂载时由应用决定是否 reset。
同一轨道只供一个呈现时钟使用。

`Theme.reduceMotion` 总是立即落到目标，显式 duration/delay 也一样。
普通播放停稳后不再请求帧。每段时长和延迟分别限制到一天，长停顿安全收敛。
输入须为有限数，非法输入抛出 `IllegalArgumentException`；中间运算避免有限端点相减溢出。

```cangjie
let track = rememberState<MotionValue>("halo.x") { MotionValue(0.5) }.value
CanvasWidget(onDrawContext: { ctx, rect =>
    let x = track.animate(ctx, target: 0.8,
        spec: AnimationSpec.automatic(duration: 180, easing: Easing.EaseOutCubic))
    ctx.renderer.fillCircle(rect.x + rect.w * x, rect.centerY(), 12.0, ctx.theme.accent)
}, transparent: true)
```

这段代码放在活动组件构建块内。`MotionValue` 提供数值采样，命中区域、焦点和业务状态仍由原组件拥有。
见 [视觉动效与可选 Kit](../../../reference/motion-studies.md)。
