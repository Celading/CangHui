[cui](../../index.md) › [cui.core](index.md) › ComponentTheme

# ComponentTheme

`ComponentTheme` 是 [`Theme`](Theme.md) 的组件级覆盖层。它保留背景、文字、强调色等语义 Token，
同时允许产品改变 Button 的状态外观/布局和 Panel 默认表面，避免每个调用点重复传入同一套样式。

```cangjie
let productTheme = Theme.light().withComponents(ComponentTheme(
    buttonStyle: Some(productButtonStyle()),
    buttonLayout: ButtonLayoutStyle(
        contentPadding: LengthInsets(18.vp, 10.vp),
        minWidth: 88.0,
        minHeight: 44.0
    ),
    panelSurface: Some(SurfaceStyle(
        Color.rgb(250, 250, 247),
        border: Color.rgba(0, 0, 0, 0),
        radius: 2.0
    ))
))
```

## 字段

- `buttonStyle`: 可选 [`ButtonStyle`](ButtonStyle.md)，同时作用于 Button 与 IconButton。
- `buttonLayout`: 标题/slot Button 的默认内边距与最小尺寸。
- `panelSurface`: 可选 Panel 默认表面；单个 `Panel.style(...)` 仍可覆盖它。

## ButtonLayoutStyle

`ButtonLayoutStyle(contentPadding, minWidth, minHeight)` 默认使用水平 12 vp、垂直 0 vp、最小宽度 72、
最小高度 38。单个 Button 可用 `contentPadding` 与 `minControlSize` 覆盖这些默认值。
