[cui](../../index.md) › cui.desktop

# cui.desktop

```cangjie
import cui.desktop.*
```

桌面应用对象包：[`DesktopApp`](DesktopApp.md) 拥有 SDL 窗口与渲染循环，驱动构建-布局-绘制-事件分发，并提供资源管理、系统文件对话框、基础光标与最小窗口尺寸等应用级设施。闲置帧被跳过（脏帧机制），`--snapshot`/`--profile` 命令行开关内置。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`DesktopApp`](DesktopApp.md) | 桌面应用对象：拥有 SDL 窗口并运行帧循环——每帧从 [`run`](DesktopApp.md#run) 的界面构建函数重建组件树、布局、分发输入、绘制。 |
