package sdl

@Test
func drawIrAsciiProjectsGeometryTextAndSymbolsDeterministically(): Unit {
    let commands = [
        DrawIrCommand("paint.fill", "", data: "\"x\":0,\"y\":0,\"width\":100,\"height\":50,\"color\":{\"r\":20,\"g\":20,\"b\":20,\"a\":255}"),
        DrawIrCommand("paint.stroke-line", "", data: "\"x1\":0,\"y1\":25,\"x2\":100,\"y2\":25,\"width\":1,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("paint.stroke-circle", "", data: "\"cx\":20,\"cy\":15,\"radius\":8,\"width\":1,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("text", "", data: "\"text\":\"HELLO\",\"x\":40,\"y\":10,\"pointSize\":12,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("symbol", "", data: "\"x\":60,\"y\":30,\"width\":30,\"height\":12,\"name\":\"play\"")
    ]
    let first = renderDrawIrAscii(commands, 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 40, rows: 12))
    let second = renderDrawIrAscii(commands, 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 40, rows: 12))
    @Expect(first, second)
    @Expect(first.contains("HELLO"))
    @Expect(first.contains("o"))
    @Expect(first.contains("[play]"))
    @Expect(first.contains("----------------------------------------"))
}
