# 开发记录

## 2026-07-04

已完成阶段 1 的本地 MVP：

- 创建独立项目 `VibeHandInputAssistant`。
- 使用 Swift + AppKit 构建 macOS 菜单栏 App。
- 支持辅助功能权限检测和打开系统设置。
- 支持全局监听 `F13/F14/F15`。
- 支持目标软件预设：
  - Codex
  - Claude
  - Claude Code
  - Kimi
  - 自定义 App
- 支持发送方式：
  - Return
  - Command + Return
- 支持豆包语音默认 `Fn down/up` 模式。
- 已生成 `.app`：

```text
.build/app/Vibe 手持输入助手.app
```

## 当前限制

- 还未实现固件刷写向导。
- 还未实现开机自启动。
- 自定义语音快捷键 UI 暂未展开，当前仍以 `Fn` 为默认。
- GitHub CLI 当前登录 token 失效，远程仓库需要重新登录后创建。

## 本地测试提醒

测试这个 App 前，建议先退出 Hammerspoon，避免 Hammerspoon 和新 App 同时监听 `F13/F14/F15`。

