# 项目文档

更新时间：2026-09-07

本目录只保留当前计划、长期有效的设计规范和发布验收资料。已经完成的一次性实施步骤、评审往返和重复交接内容不再作为项目文档维护；需要追溯时查看 Git 历史。

## 阅读顺序

1. [ROADMAP.md](ROADMAP.md)：唯一的项目级完成度与优先级入口。
2. [IMPROVEMENT_PLAN.md](IMPROVEMENT_PLAN.md)：下一阶段如何执行、每阶段何时算完成。
3. [WINDOWS_RELEASE_CHECKLIST.md](WINDOWS_RELEASE_CHECKLIST.md)：发布前自动检查和人工实机矩阵。
4. 根据改动范围读取下方对应专项规范。

## 状态判定规则

- 实现是否存在，以 `scripts/`、`scenes/` 和资源文件为准。
- 自动化是否通过，以当前源码实际运行的测试结果为准；旧日志和旧完成数字不自动继承。
- 项目级完成度只在 [ROADMAP.md](ROADMAP.md) 更新，专项文档不再重复维护一套阶段编号。
- `自动完成` 与 `人工完成` 分开记录。无头测试不能替代 Windows DPI、Alt+Tab、实体手柄和独立发行机验收。
- 新功能至少运行对应专项测试；影响主流程、存档、输入或公共 UI 时运行完整 smoke 套件。

## 当前计划

| 文档 | 作用 |
| --- | --- |
| [ROADMAP.md](ROADMAP.md) | 已完成能力、当前阻断项、后续队列和明确暂缓项 |
| [IMPROVEMENT_PLAN.md](IMPROVEMENT_PLAN.md) | 发布收口、试玩采样、内容增强的执行顺序与退出条件 |
| [BALANCE_RECORD.md](BALANCE_RECORD.md) | 遥测样本门槛、平衡信号和版本调整记录 |

## 专项规范

| 文档 | 适用范围 |
| --- | --- |
| [PRODUCT_EXPERIENCE_PLAN.md](PRODUCT_EXPERIENCE_PLAN.md) | 首次游玩、死亡复盘、中途继续、事件选择与无障碍 |
| [COMBAT_FEEL_PLAN.md](COMBAT_FEEL_PLAN.md) | 攻击节奏、命中顿帧、取消窗口和动作衔接 |
| [CHARACTER_ANIMATION_SPEC.md](CHARACTER_ANIMATION_SPEC.md) | 角色帧尺寸、脚底锚点、命名、导入与动作验收 |
| [AUDIO_PLAN.md](AUDIO_PLAN.md) | 音乐状态、音效事件、混音规则和素材替换方式 |
| [UI_DESIGN_REFRESH.md](UI_DESIGN_REFRESH.md) | 当前 UI 的色板、层级、布局和交互基线 |
| [UI_MOCKUPS.md](UI_MOCKUPS.md) | 8 张 UI 视觉参考图索引 |

## 验收与交付

| 文档 | 作用 |
| --- | --- |
| [UI_POLISH_CHECKLIST.md](UI_POLISH_CHECKLIST.md) | UI 自动回归与人工视觉检查清单 |
| [WINDOWS_RELEASE_CHECKLIST.md](WINDOWS_RELEASE_CHECKLIST.md) | Windows 构建、显示、输入、压力和存档验收 |
| [TEST_BUILD_NOTES.md](TEST_BUILD_NOTES.md) | 当前测试包说明、已知待验项和反馈模板 |
