[cui](../../index.md) › [cui.core](index.md) › ButtonStyle

# ButtonStyle

`ButtonStyle` 将主题、[`ButtonRole`](ButtonRole.md) 和连续交互状态解析为按钮外观。应用可以在单个
`Button` / `IconButton` 上调用 `buttonStyle`，也可以通过 [`ComponentTheme`](ComponentTheme.md)
一次覆盖全应用默认按钮外观。

```cangjie
let flat = ButtonStyle(resolve: {
    theme, role, state =>
    let base = theme.buttonSurface(role)
    ButtonAppearance(
        surface: SurfaceStyle(
            base.fill.lerp(theme.accentText, state.hover * 0.08),
            border: base.border,
            radius: 4.0,
            borderWidth: base.borderWidth
        ),
        foreground: match (role) {
            case ButtonRole.Normal => theme.text
            case _ => theme.accentText
        },
        ink: theme.inkColor(role: role),
        focusRadius: 4.0
    )
})
```

## ButtonVisualState

- `hover`: `0...1` 的悬停动画进度。
- `press`: `0...1` 的按压动画进度。
- `focused`: 按钮当前是否拥有焦点。

## ButtonAppearance

- `surface`: 外层填充、描边、圆角和阴影。
- `foreground`: 标题 Button 与 IconButton 的文字/图标颜色。
- `ink`: 指针或键盘激活产生的 InkWell 颜色。
- `focusRadius`: 焦点环与 InkWell 裁切圆角。

slot Button 的子树保持自己的文字和图标颜色；`ButtonAppearance.foreground` 不会隐式改写任意子树。
