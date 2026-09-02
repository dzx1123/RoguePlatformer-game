# Windows 测试包发布检查清单

## 自动检查

1. 使用 Godot 4.7.2 打开 `D:\Godot\RoguePlatformer-game`，确认无脚本解析错误。
2. 运行核心测试：动作素材、攻击连按、整局结构、固定种子、存档恢复、设置菜单与发布就绪检查。
3. 在 PowerShell 中运行：

   `powershell -ExecutionPolicy Bypass -File .\tools\verify_windows_build.ps1`

   脚本默认导出 Windows x86_64 发布包、启动导出的 EXE、等待主场景运行，并检查退出码与运行日志。当前机器只安装了发布模板；如补装调试模板，可传入 `-Configuration Debug`。

4. 自动布局检查运行：

   `Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/resolution_matrix_smoke.gd`

   真实渲染截图使用 `tests/capture_resolution_matrix.gd`，报告与截图输出到 `tests/artifacts/resolution-matrix/`。

5. 确认导出包不包含 `tests/`、`docs/`、`tools/`、开发说明与旧构建目录。

## 分辨率与显示

- 窗口模式依次检查 `1280×840`、`1600×900`、`1920×1080` 和 `2560×1440`。
- 检查全屏切换、垂直同步、Alt+Tab、窗口最小化/恢复。
- HUD 底栏不得覆盖战斗区；左右栏和中央技能栏不能越界或互相遮挡。
- 100%、125%、150% Windows 缩放下，文字仍清晰且按钮可点击。

## 输入与可访问性

- 键盘完成移动、二段跳、上下劈、冲刺、技能、宝箱、商店与暂停流程。
- 手柄完成同一流程，并检查断开、重连和菜单焦点。
- 分别验证默认效果和减弱闪光/镜头震动设置。
- 主音量、音乐、音效与语音分轨设置在重启后保持。
- 默认 Xbox 布局：左摇杆/十字键移动，A 跳跃，X 攻击，B 冲刺，Y 技能，肩键互动与切换武器。

## 30 分钟压力流程

- 自动运行：`Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/long_session_stress.gd -- --duration=1800`。
- 检查 `tests/artifacts/stress/soak_report.json` 为 `success: true`，且日志中不存在 `ERROR:`、解析错误或进度停滞。
- 连续完成至少两局或运行 30 分钟；多次连按攻击与技能，不得卡死。
- 至少经历史莱姆、哥布林、混编、四个阶段首领、商店、事件和风险宝箱。
- 反复死亡、重开、切换武器、开关设置，观察内存是否持续上涨。
- 退出后重新启动，验证进度、设置与遥测 JSON；损坏主档时应自动读取 `.bak`。

## 交付物

- EXE 与 PCK（或单文件包）、版本号、构建日期和本次变更摘要。
- `tests/release_readiness_smoke.gd`、核心测试结果与导出启动日志。
- 已知问题列表；阻断级问题为卡死、存档丢失、无法启动、输入失效和 HUD 越界。
