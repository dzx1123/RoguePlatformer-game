# GPT 实施入口 · UI 视觉刷新

监工 demon 已拍板：**按本目录设计落地**。先读完再改代码。

## 必读顺序
1. `UI_DESIGN_REFRESH.md` — 原则、色板、文案、分屏、切片 U0–U4、附录 B 实测尺寸
2. `MOCKUPS.md` — 视觉稿索引
3. `ui_mockups/*.png` — 视觉真值（气质参考；工程优先复刻层级/色/字号/文案，不强制新背景大图）
4. 对照旧截图 `../tests/artifacts/p7-current/`（若存在）

## 硬约束
- 唯一工程根：`D:\Godot\RoguePlatformer-game`
- 不借机大拆 `main.gd`；可新增小模块 `scripts/ui_theme.gd`（MoonUI）
- 中文主文案；禁止主标题级全大写英文 kicker
- 奖励层骨架保留，只换皮肤与文案
- RewardFeedback = 底栏上方细条，无全屏 veil；风险开战禁止 toast
- 改完更新 `CODEX_HANDOFF.md`；保留 `GROK_REVIEW.md` 原文
- 跑相关 `*_smoke` 与 `capture_p7_ui_preview`（若环境允许）

## 推荐切片顺序
- **先收尾** `GROK_REVIEW.md` 附录 A 的 P1（事件实际治疗数值、风险开箱无开战 toast）若尚未完成
- 然后 **U0**：MoonUI tokens + 中文 kicker + 隐藏原型文案
- 然后 **U1**：RewardFeedback 细条化
- 再 U2 入口/难度 → U3 HUD 降噪 → U4 胜利/死亡 CTA

## 交付格式
【切片】【改动文件】【验证】【风险】【请监工确认】【下一步建议】
