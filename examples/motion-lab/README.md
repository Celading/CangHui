# Motion Studio

五组视觉动效的独立消费样例：回弹、数字终端与滚动数字、焦点柔光、错峰编排、细线档案。
切换导航探索不同视觉；Replay 重播或反向，数字按钮覆盖位数变化与大整数。
可切换亮暗配色和减少动效。窄窗口使用上下结构，完整页面可滚动。

```sh
cjpm build
cjpm run -- --family 2 --theme dark
```

要求仓颉 1.2.0 以及当前仓绘源码。macOS 首次运行需先按仓库说明准备 SDL 原生库。
例如从本目录启动已编译程序：

```sh
DYLD_LIBRARY_PATH=../../sdl/.sdl3 ./target/release/bin/main --family 2 --theme dark
```

参数包括 `--family 0..4`、`--width`、`--height`、`--theme light|dark`、
`--reduced true|false`、`--number <Int64>`、`--scale`。
`--pointer true` 用于自有窗口捕获时重放一次光斑位置。

```sh
cjpm test
cuic-debug design snapshot . motion.bounce --version 2 --computed --events 'advance 1400'
python3 capture-matrix.py --output /tmp/motion-native-frames --full
```

捕获脚本运行实际 SDL 窗口，保存各帧 PNG、日志及真实时钟 manifest；帧号不等于固定毫秒或已停稳。
`CANGHUI_MOTION_DESIGN_OUTPUT` 指向已存在的目录时，测试额外导出五类×两种宽度的计算设计快照。
样例与可选 Kit 都只使用公开 `chui.*` 接口。
见 [配方接口与行为](../../manual/reference/motion-studies.md)。
