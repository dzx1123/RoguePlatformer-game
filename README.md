# 月蚀回廊

《月蚀回廊》是使用 Godot 4.7 制作的原创 2D 横版动作 Roguelite 测试版。当前已具备完整 20 房路线、三武器构筑、阶段首领、局外成长、继续游戏、设置与自动化测试。

## 当前玩法

- 移动、二段跳、上下劈、冲刺、普通攻击和武器主动技能。
- 生命、受伤无敌、击退、坠落、死亡复盘和三条命挑战流程。
- 月弧长剑、影织双刃、坠星巨刃，以及通用和武器专属强化。
- 从 12 套手工房间骨架生成可复现的 20 房种子路线。
- 普通、宝箱、精英、商店、首领、事件、挑战、风险宝箱和守点九类遭遇。
- 第 5、10、15、20 房为阶段首领；首领包含突进、弹幕、震地与阶段变化。
- 清房传送门、三选一强化、事件代价、商店购买和风险伏兵结算。
- 星屑结算、武器解锁、房间边界继续、设置与最近 60 次路线遥测。
- 键鼠和 Xbox 布局，包含改键、音量、显示与无障碍选项。

## 操作

- `A / D` 或左右方向键：移动。
- `空格`：跳跃；离地后可再跳一次。
- `W / S` 或上下方向键 + `J`：上劈 / 下劈。
- `J`：普通攻击。
- `K`：冲刺。
- `L`：武器主动技能。
- `Q`：切换已解锁武器。
- `E`：宝箱、传送门或商店互动。
- `1 / 2 / 3`：选择强化、商品或事件选项。
- `R`：重新开始路线。

Xbox 默认布局：左摇杆/十字键移动与导航，A 跳跃/确认，X 攻击，B 冲刺/返回，Y 技能，RB 互动，LB 换武器，Menu 暂停，View 重开。选择界面支持 X/Y/B 直选和 A 焦点确认。

## 运行项目

1. 使用 Godot 4.7.2 或兼容的 Godot 4 稳定版导入 `project.godot`。
2. 使用 F5 运行主场景 `scenes/Main.tscn`。

标准无头测试命令：

`D:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path D:\Godot\RoguePlatformer-game --script res://tests/<test>.gd`

项目计划、专项规范和测试入口见 [docs/README.md](docs/README.md)。

## Windows 测试包

安装与 Godot 4.7.2 匹配的 Windows x86_64 发布模板后，按需运行：

`powershell -ExecutionPolicy Bypass -File .\tools\verify_windows_build.ps1`

脚本导出到 `build/windows-verify/` 并执行启动检查。现有本地构建可能早于当前源码，发包前必须阅读 [Windows 发布验收清单](docs/WINDOWS_RELEASE_CHECKLIST.md) 和 [测试包说明](docs/TEST_BUILD_NOTES.md)，从目标提交重新生成。

## 项目结构

- `scenes/`：主场景和玩家场景。
- `scripts/`：玩法、角色、敌人、流程服务、UI、设置与存档。
- `assets/`：角色、敌人、背景、UI、着色器和音频资源。
- `tests/`：smoke、动作审计、压力测试和截图脚本。
- `tools/`：Windows 构建验证及可复现的动作/音频资源生成工具。
- `docs/`：当前路线图、专项规范和发布验收资料。

## 用户数据

Godot 用户数据目录中默认保存：

- `rogue_progress.json`：局外进度和武器选择。
- `rogue_settings.json`：输入、音量、显示和无障碍设置。
- `run_continue.json`：未完成路线的房间边界快照。
- `run_telemetry.json`：最近 60 次路线的平衡数据。

JSON 写入使用临时文件和备份恢复；修改存档字段时必须同步版本验证与恢复测试。
