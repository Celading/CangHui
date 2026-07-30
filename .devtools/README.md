# .devtools 开发辅助脚本

服务本仓库日常开发的跨平台 Python 脚本（Windows/macOS/Linux，仅依赖标准库，Python 3.8+）。
这些工具不参与构建与发布，只辅助验证与排查。

## snapshot_tool.py（快照像素工具）

示例应用经 `cjpm run --run-args "--snapshot x.bmp"` 输出渲染快照；本工具对快照做像素级处理。

```
python .devtools/snapshot_tool.py convert a.bmp a.png             # BMP 转 PNG 便于查看
python .devtools/snapshot_tool.py diff a.bmp b.bmp                # 逐像素对比；退出码 1 表示有差异
python .devtools/snapshot_tool.py diff a.bmp b.bmp --out d.png --tolerance 2
python .devtools/snapshot_tool.py check --baseline .snapbase x.bmp y.bmp   # 基线看护
python .devtools/snapshot_tool.py update --baseline .snapbase x.bmp        # 更新基线
```

diff 输出差异像素数、最大通道差与差异包围盒；`--out` 生成热图（相同处压暗、差异处标红），
定位视觉回归一目了然。`check`/`update` 以文件名为键在基线目录中留存参考图，改动渲染层或
共享组件后重跑快照即可发现视觉漂移。

## shoot_examples.py（示例画廊截图）

为 `examples/` 全部示例生成画廊截图并写入 `examples/.images/<名字>.png`，供
`examples/README.md` 的画廊表格引用。逐示例走真实渲染快照（`--snapshot`），再按整数因子
做面积平均降采样（默认压到 560px 宽以内），缩略清晰且字节量小（47 张约 1.3 MB）。

```
python .devtools/shoot_examples.py                 # 全部示例
python .devtools/shoot_examples.py mail richtext   # 只重拍指定示例
python .devtools/shoot_examples.py --max-width 560
```

改动示例外观后重拍对应几张即可；退出码非零表示有示例拍摄失败（清单在输出末尾）。

## bench_compare.py（基准 A/B 对比）

对比两组 bench 采集（`@@RESULT` 行）的逐用例耗时。每侧可给多个采集文件，同用例跨文件取
最小值（对 E 核调度、后台抢占等单向噪声最稳健），再逐用例算 B/A 比值与中位比值。

```
cd bench/micro && cjpm run --skip-build > run1.txt        # 采集若干次
python .devtools/bench_compare.py --a old1.txt old2.txt --b new1.txt new2.txt
```

与 `bench/run.py --check`（对历史基线的相对同侪门禁）互补：本工具适合两个代码状态在同一台
机器上的直接 A/B（例如 git worktree 出一个旧状态交替采样），机器态在比值中互相抵消。
退出码 1 表示有用例慢于阈值（默认 1.25x）。

## 约定

- 脚本只读仓库与指定输入，除明示的输出文件外不落盘、不改动源码。
- 输出使用 UTF-8（脚本内部已 `reconfigure`），Windows 控制台乱码时可设
  `PYTHONIOENCODING=utf-8` 或改用重定向到文件。
- 一次性代码改写（codemod）不放这里，用完即弃；这里只放可重复使用的工具。
