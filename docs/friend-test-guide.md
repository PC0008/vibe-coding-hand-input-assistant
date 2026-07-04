# Vibe 手持输入助手朋友测试指南

## 发送给朋友的文件

当前测试包：

```text
release/VibeHandInputAssistant-0.1.0.zip
```

朋友解压后会得到：

```text
Vibe 手持输入助手.app
```

## 安装步骤

1. 把 `Vibe 手持输入助手.app` 拖到 `/Applications`。
2. 双击打开。
3. 如果 macOS 提示来自未认证开发者，小范围测试时可在系统设置里允许打开。
4. 打开系统设置：

```text
隐私与安全性 -> 辅助功能
```

5. 添加并开启：

```text
/Applications/Vibe 手持输入助手.app
```

6. 重新打开 App。
7. 蓝牙连接：

```text
StickS3 Codex Remote
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

