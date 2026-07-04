# Vibe Coding手持输入助手朋友测试指南

## 发送给朋友的文件

当前测试包：

```text
release/VibeCodingHandInputAssistant-0.1.2.dmg
```

朋友打开 DMG 后会看到：

```text
Vibe Coding手持输入助手.app
```

## 安装步骤

1. 打开 DMG。
2. 把 `Vibe Coding手持输入助手.app` 拖到 `/Applications`。
3. 到“应用程序”里右键 App，选择“打开”。
4. 如果 macOS 提示来自未认证开发者，小范围测试时可在系统设置里允许打开。
5. 如果 macOS 提示“已损坏，无法打开”，打开终端执行：

```bash
xattr -dr com.apple.quarantine "/Applications/Vibe Coding手持输入助手.app"
```

6. 打开系统设置：

```text
隐私与安全性 -> 辅助功能
```

7. 添加并开启：

```text
/Applications/Vibe Coding手持输入助手.app
```

8. 重新打开 App。
9. 蓝牙连接：

```text
Vibe Coding Remote
```

## 使用方式

| 硬件按钮 | 操作方式 | 作用 |
| --- | --- | --- |
| 右侧按钮 | 单击一次 | 打开或切回 App 设置里的目标软件，例如 Codex、Claude、Kimi 或自定义 App。 |
| 正面蓝色按钮 | 按住不放 | 触发语音输入。默认对应 Mac 的按住 `Fn` 语音，也可以在 App 里设置自定义快捷键。 |
| 正面蓝色按钮 | 松开 | 结束语音输入。 |
| 正面蓝色按钮 | 快速双击 | 发送当前输入内容。发送方式可选择 `Return` 或 `Command + Return`。 |
| 左侧按钮 | 电源相关操作 | 当前不作为输入控制键使用。 |

推荐操作流程：

1. 在 App 里选择目标软件，例如 `Codex`。
2. 确认辅助功能权限已开启。
3. 在蓝牙里连接 `Vibe Coding Remote`。
4. 在任意桌面按右侧按钮，切回目标软件。
5. 按住正面蓝色按钮说话，松开结束。
6. 确认文字无误后，双击正面蓝色按钮发送。

硬件屏幕会显示连接状态、当前动作和大号电量条。电脑端 App 设置面板也会显示电量，默认约每 30 秒刷新一次。

## 目标软件

设置页可选择：

- Codex
- Claude
- Claude Code
- Kimi
- 自定义 App

## 固件烧录

v0.1.2 更新了 StickS3 屏幕电量条和电脑端电量读取逻辑。升级 App 后，需要把 StickS3 用 USB 线连接到电脑，在 App 设置页点击“展开设备烧录”，检测到串口后点“一键烧录”。烧录完成后拔掉 USB 线，再到蓝牙里连接 `Vibe Coding Remote`。

## 注意

当前测试版是 ad-hoc 签名，不是正式 Developer ID 签名。朋友第一次安装时仍可能遇到 macOS 安全提示。

正式产品版应使用 Apple Developer ID 签名和公证，避免手动绕过安全提示。

详细图文/排障说明见：

```text
docs/Vibe Coding手持输入助手-Mac安装与常见提示处理.docx
```
