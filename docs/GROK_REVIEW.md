# Grok Bot 审查回传

状态：第一轮审查完成
审查者：demon（Grok Bot）
审查基线：`f4fafca` + 未提交 UI / 奖励层改动（含 `scripts/reward_feedback.gd`、`tests/reward_layer_smoke.gd`）
审查时间：2026-09-04

> 本文件由监工写入。Codex 只读；按下面问题改代码与测试后更新 `CODEX_HANDOFF.md`。

## 总结

- 审查范围：`git diff` + 新增 reward 相关脚本；对照 `CODEX_HANDOFF.md`
- 结论：**方向正确，可继续；合入前先清下面 P1。** 奖励层、胜利摘要、非阻断确认条、标题页暂停物理——代码属实。
- 是否存在 P0：**否**（静态审查）
- 「48/48 smoke」本次**未复跑**；下一交付必须附命令与退出码。

## 已核实属实

- `RewardLayerMode` + `_configure_reward_layer` 统一 relic/shop/event/victory
- `RewardFeedback` toast，`mouse_filter = IGNORE`
- 普通宝箱用 `heal` 返回值更新提示，避免满血误报
- `_set_entry_gameplay_suspended` + entry smoke 防标题页坠落
- 有继续存档时主菜单优先 focus「继续游戏」

## 问题 1

- 优先级：P1
- 标题：标题/难度页悬挂不完整（只关了 player physics_process）
- 证据：`scripts/main.gd` → `_set_entry_gameplay_suspended`
- 修改建议：标题+难度全程同一 suspend；补 process/输入冻结；扩展 `entry_flow_smoke` 覆盖难度页各等待 >=1s
- 禁止大拆 `main.gd`

## 问题 2

- 优先级：P1
- 标题：`reward_layer_smoke` 固定 await 在减弱动效下可能假红
- 证据：`reward_feedback.gd` shortened hold；smoke 固定 0.42/0.90
- 修改建议：smoke 强制 `set_reduced_motion(false)` 或轮询 snapshot；开/关减弱动效各跑一次均 PASS

## 问题 3

- 优先级：P2
- 标题：风险宝箱世界提示不更新真实恢复量（`set_resolved_reward` 对 `_is_risk` 直接 return）
- 修改建议：结算后更新或隐藏提示；补一条断言

## 问题 4

- 优先级：P2
- 标题：胜利页 `unlocked_names.trim_prefix("；")` 脆弱
- 修改建议：规范字符串契约；smoke 覆盖无解锁/有解锁文案

## 问题 5（观察项）

- 设置中途切换减弱动效未刷新 RewardFeedback；下次动设置管线时再做

## 给 Codex 的下一刀

【切片】稳住奖励层：悬挂完整性 + toast 测试抗 flaky + 风险箱提示 + 胜利解锁文案
【范围】仅 P1/P2；禁止新系统、大拆 main、再写协作文档
【验证】entry_flow_smoke、reward_layer_smoke、完整 *_smoke；写明 Godot 路径与通过数
【回传】更新 `docs/CODEX_HANDOFF.md`；保留本审查原文（可追加已修复对照）

---

## 附录 A · 第二趟静态+抽样实测（同日）

补充说明：本趟实跑 eward_layer_smoke / entry_flow_smoke / controller_interaction_smoke / main_architecture_smoke 均 PASS；仍未跑满 48。Continue 焦点为 HEAD 已有逻辑，勿当本轮新功能重做。

### 追加问题 A1（P1）
- 标题：事件确认条仍展示承诺治疗量，满血会误报
- 证据：_resolve_event_choice 用 choice.description（如「恢复 40 生命」）做 feedback detail；宝箱路径已用 estored_health，事件未对齐
- 修改：事件 rest/heal/gold 等用实际结算值拼 detail/status；满血不得显示恢复 40
- 验收：满血选 rest → feedback 恢复为 0 或「生命已满」；金币仍按实际扣；补 smoke

### 追加问题 A2（P1）
- 标题：风险开箱瞬间全屏确认条干扰伏兵战开局
- 证据：风险分支在刷伏兵前 _present_reward_feedback；veil 全屏 + z_index 80
- 修改：风险开箱不要 present（可留 _set_status）；肃清发奖路径保留真实数值确认条
- 验收：开箱后 1s 内 RewardFeedback 不可见；肃清后可见且数字正确

### 追加问题 A3（P2）
- 标题：胜利页无焦点 CTA，只能靠 restart（R / View）
- 修改：胜利态主按钮 + ensure focus，或 accept/interact 与 hint 一致
- 验收：手柄 A 能离开胜利页

### 追加问题 A4（P2）
- 标题：orce_open 先写满额治疗再靠 set_resolved_reward 纠正
- 修改：未结算前不写满额治疗数字；由 main 唯一写文案
- 验收：满血开箱全程不出现「生命 +24」类满额文案

### 修订后的下一刀（覆盖前文队列）
优先 A1、A2，再原审查 P1 悬挂/测试抗 flaky，再 A3/A4 与原文 P2。禁止新系统、大拆 main、再写协作文档。跑相关 smoke + 全量后更新 CODEX_HANDOFF；保留本文件原文。