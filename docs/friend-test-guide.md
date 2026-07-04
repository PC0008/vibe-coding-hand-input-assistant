# Vibe Coding手持输入助手朋友测试指南

## 发送给朋友的文件

当前测试包：

```text
release/VibeCodingHandInputAssistant-0.1.0.dmg
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

- 右侧按钮：打开/聚焦设置里的目标软件。
- 正面蓝色按钮按住：触发豆包语音输入。
- 正面蓝色按钮松开：结束语音输入。
- 正面蓝色按钮双击：发送。

## 目标软件

设置页可选择：

- Codex
- Claude
- Claude Code
- Kimi
- 自定义 App

## 注意

当前测试版是 ad-hoc 签名，不是正式 Developer ID 签名。朋友第一次安装时仍可能遇到 macOS 安全提示。

正式产品版应使用 Apple Developer ID 签名和公证，避免手动绕过安全提示。

详细图文/排障说明见：

```text
docs/Vibe Coding手持输入助手-Mac安装与常见提示处理.docx
```
