# Vibe Coding手持输入助手

`Vibe Coding手持输入助手` 是一个开源 macOS App，用来配合 M5Stack StickS3 手持遥控器控制 Codex、Claude、Claude Code、Kimi 或自定义 AI 软件。

这个项目当前主要面向 **Mac 电脑**。如果只是想直接使用，请下载打包好的 DMG 安装包；如果想二次开发或移植到其他平台，可以下载源代码后自行修改。

核心功能：

- 监听 StickS3 作为蓝牙键盘发出的 `F13/F14/F15`。
- `F13` 打开/聚焦目标软件。
- `F14` 按下/松开触发语音输入。
- `F15` 发送当前输入。
- 支持录制自定义语音快捷键。
- StickS3 屏幕显示中文状态和大号电量条。
- 内置 StickS3 一键烧录工具。
- 输出可拖到 Applications 的 DMG 安装包。

## 直接下载安装

Mac 用户可以直接点击下载最新版 DMG：

```text
https://github.com/PC0008/vibe-coding-hand-input-assistant/releases/download/v0.1.3/VibeCodingHandInputAssistant-0.1.3.dmg
```

下载后双击 DMG，把 `Vibe Coding手持输入助手` 拖到 `Applications / 应用程序`。

如果想查看所有历史版本，可以打开 Releases 页面：

```text
https://github.com/PC0008/vibe-coding-hand-input-assistant/releases
```

当前测试版使用 ad-hoc 签名，没有做 Apple Developer ID 公证。首次在朋友电脑打开时，macOS 可能提示“无法验证开发者”或“App 已损坏”。处理方式见：

```text
docs/Vibe Coding手持输入助手-Mac安装与常见提示处理.docx
```

也可以直接下载在线 Word 教程：

```text
https://github.com/PC0008/vibe-coding-hand-input-assistant/releases/download/v0.1.3/VibeCodingHandInputAssistant-Mac-Install-Guide-0.1.3.docx
```

常用处理命令：

```bash
xattr -dr com.apple.quarantine "/Applications/Vibe Coding手持输入助手.app"
```

然后右键 App，选择“打开”，并在系统设置中开启辅助功能权限。

## 按钮与操作方式

StickS3 手持硬件有三个主要按键位置，其中左侧电源键不参与日常输入控制。

| 硬件按钮 | 操作方式 | 作用 |
| --- | --- | --- |
| 右侧按钮 | 单击一次 | 打开或切回设置里选择的目标软件，例如 Codex、Claude、Kimi 或自定义 App。 |
| 正面蓝色按钮 | 按住不放 | 触发语音输入。默认对应 Mac 上的 `Fn` 按住语音，也可以在 App 里改成自定义快捷键。 |
| 正面蓝色按钮 | 松开 | 结束语音输入。 |
| 正面蓝色按钮 | 快速双击 | 发送当前输入内容。发送方式可在 App 里选择 `Return` 或 `Command + Return`。 |
| 左侧按钮 | 长按/电源相关操作 | 作为设备电源/系统按键使用，当前软件不把它作为输入控制键。 |

推荐使用流程：

1. 在 App 里选择目标软件，例如 `Codex`。
2. 确认辅助功能权限已开启，并在蓝牙里连接 `Vibe Coding Remote`。
3. 在任何桌面按右侧按钮，切回目标软件。
4. 按住正面蓝色按钮说话，松开后结束语音输入。
5. 检查文字无误后，双击正面蓝色按钮发送。

硬件屏幕会显示连接状态、当前动作和大号电量条。为了避免 macOS 蓝牙电量缓存误读，电脑端 App 不再显示设备电量；电量以 StickS3 屏幕为准。v0.1.3 调整了固件屏幕布局，升级后需要在 App 里重新烧录 StickS3。

## 适用平台

### macOS

当前 App 端只支持 macOS。它使用 macOS 的辅助功能权限、全局键盘事件监听和 `NSWorkspace` 来完成：

- 打开/聚焦目标 AI 编程软件。
- 按住触发语音输入。
- 双击发送当前输入。

### Windows / 其他平台

当前仓库没有现成 Windows App。StickS3 固件和按键协议可以复用，硬件会发送 `F13/F14/F15`：

- `F13`：打开/聚焦目标软件。
- `F14`：语音输入按下/松开。
- `F15`：发送。

但 Windows 端不能只“改一下 Codex 名称”就直接使用，需要重新实现电脑端程序，包括：

- 全局监听 `F13/F14/F15`。
- 启动或聚焦目标软件。
- 模拟 Windows 上对应的语音输入快捷键。
- 处理权限、后台运行、托盘图标和安装包。

换句话说，Windows 版可以参考本项目协议和界面逻辑移植，但需要单独开发。Windows 用户或开发者可以下载本项目源代码，然后用 Codex、Claude Code 等 AI 编程工具做二次开发，把电脑端改造成 Windows 版本；核心思路很简单，就是复用 StickS3 发出的 `F13/F14/F15`，再在 Windows 上实现监听、打开软件和模拟快捷键。

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
release/VibeCodingHandInputAssistant-0.1.3/Vibe Coding手持输入助手.app
release/VibeCodingHandInputAssistant-0.1.3.zip
```

## 构建 DMG

```bash
scripts/build-dmg.sh
```

构建产物位于：

```text
release/VibeCodingHandInputAssistant-0.1.3.dmg
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
