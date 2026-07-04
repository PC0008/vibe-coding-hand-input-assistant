# Vibe 手持输入助手

`Vibe 手持输入助手` 是一个 macOS 菜单栏 App，用来配合 M5Stack StickS3 手持遥控器控制 Codex、Claude、Claude Code、Kimi 或自定义 AI 软件。

当前 MVP 目标：

- 监听 StickS3 作为蓝牙键盘发出的 `F13/F14/F15`。
- `F13` 打开/聚焦目标软件。
- `F14` 按下/松开触发豆包语音输入。
- `F15` 发送当前输入。
- 提供辅助功能权限检测、目标软件设置和基础测试菜单。

## 本地运行

```bash
swift run
```

第一次运行需要在 macOS 系统设置中给终端或构建出的 App 开启辅助功能权限。

## 构建 .app

```bash
scripts/build-app.sh
```

构建产物位于：

```text
.build/app/Vibe 手持输入助手.app
release/VibeHandInputAssistant-0.1.0/Vibe 手持输入助手.app
release/VibeHandInputAssistant-0.1.0.zip
```
