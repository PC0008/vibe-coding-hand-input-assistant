# Vibe Coding手持输入助手

`Vibe Coding手持输入助手` 是一个 macOS App，用来配合 M5Stack StickS3 手持遥控器控制 Codex、Claude、Claude Code、Kimi 或自定义 AI 软件。

核心功能：

- 监听 StickS3 作为蓝牙键盘发出的 `F13/F14/F15`。
- `F13` 打开/聚焦目标软件。
- `F14` 按下/松开触发语音输入。
- `F15` 发送当前输入。
- 支持录制自定义语音快捷键。
- 内置 StickS3 一键烧录工具。
- 输出可拖到 Applications 的 DMG 安装包。

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
.build/app/Vibe Coding手持输入助手.app
release/VibeCodingHandInputAssistant-0.1.0/Vibe Coding手持输入助手.app
release/VibeCodingHandInputAssistant-0.1.0.zip
```

## 构建 DMG

```bash
scripts/build-dmg.sh
```

构建产物位于：

```text
release/VibeCodingHandInputAssistant-0.1.0.dmg
```

当前版本使用 ad-hoc 签名，不做 Apple Developer ID 公证。首次在朋友电脑打开时，macOS 仍可能出现安全提示。

## 权限说明

App 的 Bundle ID 是：

```text
com.zhiduoxing.vibe-coding-hand-input-assistant
```

如果从旧版 `Vibe 手持输入助手` 升级，需要在系统设置的“隐私与安全性 -> 辅助功能”里删除旧条目，再给新版 `Vibe Coding手持输入助手` 重新授权。

## 作者

作者：智多星  
个人微信：369076317
