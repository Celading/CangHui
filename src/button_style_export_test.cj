package cui

@Test
func umbrellaExportsComponentThemeAndButtonStyle(): Unit {
    let style = ButtonStyle(resolve: {
        theme, role, state => ButtonAppearance(
            surface: theme.buttonSurface(role),
            foreground: theme.text,
            ink: theme.inkColor(role: role),
            focusRadius: if (state.focused) { 12.0 } else { 8.0 }
        )
    })
    let theme = Theme.light().withComponents(ComponentTheme(buttonStyle: Some(style)))
    @Expect(theme.components.buttonStyle.isSome())
    @Expect(theme.components.buttonLayout.minHeight, Float32(38.0))
}
