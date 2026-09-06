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

补充说明：本趟实跑 
eward_layer_smoke / entry_flow_smoke / controller_interaction_smoke / main_architecture_smoke 均 PASS；仍未跑满 48。Continue 焦点为 HEAD 已有逻辑，勿当本轮新功能重做。

### 追加问题 A1（P1）
- 标题：事件确认条仍展示承诺治疗量，满血会误报
- 证据：_resolve_event_choice 用 choice.description（如「恢复 40 生命」）做 feedback detail；宝箱路径已用 
estored_health，事件未对齐
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

---

## 最终签收 · U0/U1 + U2（2026-09-05 · demon）

### 结论
- 奖励层 P1/P2（A1–A4）与 UI U0/U1：**通过**
- UI U2 入口/难度（对照图 01/08）：**通过**（可开 U3）
- 未把 HUD/商店价格徽章细节/事件代价分行/死亡页标成全套完成

### 实机截图依据
- U0/U1：	ests/artifacts/ui-refresh-u0-u1/（upgrade/shop/victory 等）— 中文 kicker、金/青主题、胜利「再启一轮」可见
- U2：	ests/artifacts/ui-refresh-u2/menu.png、menu_continue.png、difficulty.png — 继续旅程金主 CTA、开启新局青次级、难度焦点顶条、明确返回
- 回归：交接称 49/49 smoke；抽查 entry_ui_refresh_smoke / 全量日志目录含 PASS 标记

### 观察项（不阻断 U3）
1. 选牌 kicker 文案疑似「月弧遗物」——请核对是否应为「月弧遗物」
2. 商店截图中 HUD 金币与状态条金币不一致（测试夹具/调试态），确认非玩家路径
3. 模态奖励/胜利时底栏 HUD 仍完整显示，压暗不够——并入 U3
4. 走路新帧若本机仍为旧拧腿资源，与 UI 签收无关，另开同步

### 下一刀
只开 **U3**：图 02 战斗 HUD 降噪（约 96px 底栏、左上小字房号、状态芯片、模态时降权）。禁止改战斗数值、禁止自动打包。

---

## 附录 · ui-refresh-final 视觉签收（demon · 2026-09-05 11:55 CST）

对照：`tests/artifacts/ui-refresh-final/` ↔ `docs/ui_mockups/`（U0–U2 已签；本附录补 U3/U4 观察）。

### U3 战斗 HUD（`combat.png`，10:36 拍摄）
- **已到位**：底栏约 96px、左血/中技/右武分区清晰；顶栏房间文案已是 `第 N/20 房 · S####`。
- **改前残留（该截图）**：左上房间仍有深色胶囊壳；demon 已把 `RoomCard` 改为透明、`RoomProgress` 用 Caption/`TEXT_SECONDARY`，**需 Grok 应用重截** `tests/artifacts/ui-refresh-u3/`。
- **状态芯片**：本帧中心条是进房提示（RewardFeedback），不是 CombatStatus——芯片需另抓一帧。
- **模态压暗**：见奖励层。

### 奖励层（`upgrade.png`）
- **通过**：月弧遗物三选一骨架正常；底栏 HUD 未抢戏（`_sync_combat_hud_visibility` 生效）。

### U4 胜利（`victory.png`）
- **通过**：封印叙事、三列结算、解锁行、主 CTA 清晰。
- **记入 U4**：若设计要双 CTA，本图仅单主按钮——不挡 U3。

### 结论
| 切片 | 对 final 截图 | 对当前代码（11:52+） |
| --- | --- | --- |
| U3 | 基本合格，房间壳需重截验证 | 已落地；等 Grok 应用跑测 + `ui-refresh-u3` |
| U4 | 主路径可玩可懂 | 未在本回合改代码 |

**下一步（Grok 应用）**：按 `docs/CODEX_HANDOFF.md` 顶部 U3 节跑 smoke、建 `ui-refresh-u3`、回写本文件。口令「读取 Grok 评审并继续」仅在需要 demon 跟评审返工时再用。

---

## U3 跑测 + 重截签收（Grok 应用 · 2026-09-05）

对照：`docs/CODEX_HANDOFF.md` 顶部 U3 节；截图 `tests/artifacts/ui-refresh-u3/`。未改战斗数值，未打包，未开 U4 / 无障碍 / 实机验收。

### 测试

Godot 4.7.2，`--path D:\Godot\RoguePlatformer-game`，`Start-Process -Wait -PassThru`：

| 测试 | 退出码 | 日志 |
| --- | --- | --- |
| `ability_hud_smoke.gd` | 0 + PASS | `tests/artifacts/ui-refresh-u3/ability_hud_smoke.log` |
| `entry_ui_refresh_smoke.gd` | 0 + PASS | `tests/artifacts/ui-refresh-u3/entry_ui_refresh_smoke.log` |
| `hud_result_ui_smoke.gd` | 0 + PASS | `tests/artifacts/ui-refresh-u3/hud_result_ui_smoke.log` |
| `reward_layer_smoke.gd` | 首跑日志已有 PASS、进程退出 -1（与既有原生退出观察同类）；复跑 **0 + PASS** | `reward_layer_smoke.log` / `reward_layer_smoke-recheck.log` |

本轮未重跑全部 50 项。`scripts/` 中无「月狐」；选牌 kicker 现为「月弧遗物 · 三选一」。

### 重截（均 1280×840、退出 0）

| 文件 | 状态 |
| --- | --- |
| `combat.png` | 左上 Caption `第 1/20 房 · S####`，无深色胶囊壳；96px 底栏左生命 / 中 JKL / 右武器；进房时状态芯片已在底栏上方 |
| `status.png` | 金边芯片「清理房间 · 剩余敌人 3」，与进房 toast 区分开 |
| `toast.png` | 奖励确认条「已获得「锋刃磨砺」」；底栏压暗、房间 Caption 仍完整不透明 |
| `upgrade.png` | 选牌模态硬藏战斗 HUD；kicker「月弧遗物 · 三选一」 |

为抓芯片/确认条帧，仅在 `tests/capture_p7_ui_preview.gd` 增加 `status` / `toast` 预览模式，未改 HUD 布局实现。

### 结论

- **U3 通过。** 房间壳已去掉，状态芯片可单独成帧，奖励 toast 时码头软压暗（约 0.38），选牌模态硬隐藏底栏。
- 观察（不阻断、不返工）：芯片 Y=704，会叠在最下层石台立面上，读得见但不像「浮在 UI 安全带」；全量 50 smoke 本轮未重跑。
- **不开 U4。** 胜利双 CTA、无障碍、实机验收仍按交接停住。

demon 无需为 U3 房间壳再改代码。若要跟芯片叠石台或全量回归，用口令「读取 Grok 评审并继续」。

---

## 附录 · U3 自跑验证签收（demon · 2026-09-05 12:02 CST）

不再等待传话：demon 自行跑测 + 截图 + 本评审。

### Smoke（exit 0 + PASS）
| 测试 | 结果 | 日志 |
| --- | --- | --- |
| ability_hud_smoke | PASS | `tests/artifacts/ui-refresh-u3/ability_hud_smoke.log` |
| reward_layer_smoke | PASS | `tests/artifacts/ui-refresh-u3/reward_layer_smoke.log` |
| entry_ui_refresh_smoke | PASS | `tests/artifacts/ui-refresh-u3/entry_ui_refresh_smoke.log` |
| hud_result_ui_smoke | PASS | `tests/artifacts/ui-refresh-u3/hud_result_ui_smoke.log` |

（stderr 仅有退出泄漏 WARNING，无 SCRIPT ERROR / FAIL。）

### 截图（`tests/artifacts/ui-refresh-u3/`）
- `combat.png`：房间 Caption 无面板壳；96px 月弧顶线码头；左血/中技/右武。
- `status_chip.png`：码头上方金边状态芯片（清理房间 · 剩余敌人）。
- `reward_toast_dim.png`：奖励 toast 时码头压暗仍可读。
- `upgrade_modal.png`：选牌模态下底栏硬隐藏；kicker 为「月弧遗物」。

### 结论
**U3 签收通过。** 历史观察「月狐」已按截图与文案更正为「月弧」。下一刀：**走路 8 帧装回当前机**（若仍缺）或 **U4 胜利双 CTA**，不改战斗数值、不自动打包。

---

## 附录 · U4 胜利双 CTA（Grok Bot · 2026-09-05 12:07 CST）

对照任务：胜利页主/次双按钮（再来一局 + 返回标题），不改战斗数值、不打包。

### 实现摘要（`scripts/main.gd`）
- 主 CTA `VictoryRestart` 左移至 `(200,246)` 尺寸 `280x54`（印章主色保留）。
- 次 CTA `VictoryTitleReturn` 于 `(540,246)` 尺寸 `280x54`；次级面板描边；`pressed` -> `_return_to_main_menu()`。
- 左右 focus neighbor 与 death_recap 同构；默认焦点仍落在 restart（冒烟契约不变）。
- 文案：键盘 `返回标题  [Esc]` / 手柄 `返回标题  [B]`；底栏 hint 同时点名两个 CTA。

### Smoke
| 测试 | 退出码 | 结果 |
| --- | --- | --- |
| `reward_layer_smoke.gd` | 0 | PASS |
| `hud_result_ui_smoke.gd` | 0 | PASS |
| `controller_interaction_smoke.gd` | 0 | PASS |

### 截图
- `tests/artifacts/ui-refresh-u3/victory_dual_cta.png`（windowed capture_p7_ui_preview `victory`）

### 结论
**U4 PASS。** 双 CTA 已落地且三项相关 smoke 全绿；主焦点与「再来一局」文案契约保持。

---

## 附录 · P7 无障碍切片（2026-09-05 12:27 CST · Grok Bot）

- 范围：大号字 + 高对比（设置持久化 / 设置页开关 / HUD 呈现）；减弱闪光/震动保持原样。
- 证据：`accessibility_settings_smoke`、`settings_persistence_smoke`、`menu_settings_smoke` 均 exit 0；预览 `tests/artifacts/ui-refresh-u3/settings_a11y.png`。
- 观察：字号用绝对基准（CAPTION 13→15、BODY 16→18、micro 12→14），重复 apply 不叠加；未改战斗数值与打包。

---

## 附录 · 状态芯片抬高（demon · 2026-09-05 12:28 CST）

针对观察「芯片叠在底层石台」：`StatusToast` Y 改为 `HUD_DOCK_TOP - 52`（原 -40），`z_index` 90/91；`RewardFeedback` `z_index` 95。U3 布局未回滚。`ability_hud` / `hud_result` / `accessibility` 复测 PASS。

---

## 收口核对（Grok 应用 · 2026-09-05）

自行读 `CODEX_HANDOFF.md` 顶部与本文件 U4 / 无障碍 / 芯片附录；未改战斗数值、未打包。

### 已核实

- **U3**：此前已签收；房间 Caption 无壳。
- **U4**：`victory_dual_cta.png` 主「再来一局 [Enter]」+ 次「返回标题 [Esc]」，布局可读。
- **无障碍切片**：设置页有「大号字」「高对比」开关；`SAVE_VERSION` 6；`settings_a11y.png` 可见。交接称 `accessibility_settings` / `settings_persistence` / `menu_settings` 退出 0；全量摘要 `FULL_SMOKE_SUMMARY.md` 为 **51/51 PASS**。
- **芯片抬高**：代码 `HUD_DOCK_TOP - 20 - 32`（即 -52，Y=692），`z_index` 90/91。重截 `tests/artifacts/ui-refresh-u3/status_chip_raised.png`：芯片落在底栏上方空隙，不再画在整块石台立面上。该观察项关闭。

### 观察（不阻断主线）

设置「显示与辅助」一行过挤：`DamageNumbersToggle` 在 `(936,248)` 宽 210，与 `LargeTextToggle (900,248)` 重叠，截图里会读成「大号显示伤害数字」。高对比开关仍单独可见。若下一刀动设置页，把伤害数字开关下移或把大号字/高对比收到下一行。

### 结论

**UI 刷新主线 U0–U4 + 无障碍最小切片 + 芯片抬高：通过。** 下一步不要自动打包；不要开成就/图鉴/新系统。设置页开关重叠仅在下次改设置布局时处理。`docs/UI_POLISH_CHECKLIST.md` 里「字号/高对比」仍勾未完成，与代码不符，由实现侧改文档即可。

---

## 附录 · 走路白边/发色/流畅度（demon · 2026-09-05 12:48 CST）

用户反馈：走路不流畅、白边、头发突然变色。

### 处理
1. 重处理 `hero_run_0..7`：硬切 alpha、去白边软边；第 4/6 帧黑发噪点从相邻帧银发覆盖并统一发色。
2. `scenes/Player.tscn`：`HeroSprite` / `SkillPoseEcho` `texture_filter` `1→0`（最近邻）。
3. `hero_run_*.png.import`：`fix_alpha_border=false`（避免导入扩边白晕）。
4. `player.gd`：`RUN_PIXELS_PER_FRAME` `19→24`（切帧略慢更稳）。
5. 备份：`assets/characters/frames_polished_run_backup_clean_20260905_124739/`

### 验证
`character_frame_spec_smoke` / `player_animation_smoke` / `animation_motion_audit` PASS。

请实机跑几步确认白边与发色跳变是否消失。
