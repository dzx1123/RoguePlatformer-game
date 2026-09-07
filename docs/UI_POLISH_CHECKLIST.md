# UI 验收清单

更新时间：2026-09-07
状态：工程实现完成；自动回归已覆盖，剩余项目并入 Windows 人工验收。

## 已实现基线

- 标题页月夜背景、主次行动和局外进度摘要。
- 难度卡焦点、玩法节奏说明和明确返回操作。
- 1280×720 三段式底部 HUD、左上房间 Caption、首领条和短状态芯片。
- 强化、商店、事件和胜利共用奖励层；宝箱与选择结果使用非阻断确认条。
- 清房后生成可接近并交互的月蚀传送门。
- 死亡和胜利均提供明确的主要/次要按钮及键鼠/手柄焦点。
- 减弱效果、大号字、高对比、色觉辅助和 90%/100%/110% HUD 缩放。
- 设置页分行布局，显示辅助开启后仍保持可读。

## 自动回归

涉及 UI 时至少选择对应测试：

- 入口与难度：`entry_flow_smoke.gd`、`entry_ui_refresh_smoke.gd`。
- HUD 与结果页：`ability_hud_smoke.gd`、`hud_result_ui_smoke.gd`。
- 奖励与转场：`reward_layer_smoke.gd`、`room_exit_portal_smoke.gd`。
- 输入焦点与点击命中：`controller_interaction_smoke.gd`、`mouse_hit_target_smoke.gd`、`menu_settings_smoke.gd`。
- 显示辅助：`accessibility_settings_smoke.gd`、`settings_persistence_smoke.gd`。
- 尺寸与窗口：`resolution_matrix_smoke.gd`、`window_mode_smoke.gd`、`display_settings_runtime_smoke.gd`。

影响共享主题、HUD 构建器、主菜单或奖励层时运行完整 smoke 套件。

## 人工视觉检查

- 标题、难度、战斗、首领、强化、商店、事件、宝箱、风险伏兵、暂停、设置、死亡和胜利各检查一次。
- 键盘、鼠标和实体手柄均能看见唯一焦点，取消/返回不会进入错误页面。
- 伤害数字、状态芯片、奖励确认条和首领条不相互遮挡。
- 大号字、高对比、色觉辅助和三档 HUD 缩放可组合开启，重复切换不累乘。
- 四档 16:9 分辨率下无关键控件越界；窗口大小改变后模态层仍居中。
- Windows 125%/150% DPI、Alt+Tab、最小化/恢复、手柄断连/重连按发布清单实测。

## 约束

- 自动截图和 smoke 通过不替代 DPI 与实体设备检查。
- 未经明确要求不导出或覆盖发行包。
- UI 修复不顺带改战斗数值，也不提前开发成就、图鉴等长期系统。
