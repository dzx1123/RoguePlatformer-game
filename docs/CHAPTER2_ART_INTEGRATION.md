# 第二章美术接入记录

日期：2026-09-17。通过内置 imagegen 生成并复制到项目资源目录，游戏实际使用以下文件。

| 资源 | 用途 |
| --- | --- |
| `assets/chapter2/forge_background_v1.png` | 暖色熔炉背景 |
| `assets/chapter2/cooling_court_v1.png` | 蓝色冷却庭背景 |
| `assets/chapter2/forge_characters_v1.png` | 投掷者、守卫、甲虫、监炉者各四个关键姿势，透明背景 |

主角沿用游戏已有资源。背景由 `forge_background_art.gd` 加载；角色由 `forge_character_art.gd` 裁取透明有效区域，保持各行缩放比例和脚底基线，按朝向绘制。图像不改变攻击判定、碰撞体或危险预警。角色图集实际为 1254×1254，行分界按实际内容配置，不能假定生成结果是等高四行。通过 Texture2D 读取导入后的资源，支持导出包。

当前是状态驱动的关键姿势切换，尚非完整逐帧动画；平台仍使用现有程序绘制结构。正常伤害通关、动画衔接、音效和手柄体验仍需后续验收。打包截图：`test_output/chapter2_exported_art.png`。

## 暖色背景提示词

Create a production-ready 2D side-scrolling dark fantasy game background, wide landscape 1536x1024. Ember Forge cathedral interior: vast layered iron arches, distant monumental furnace tower, chains, copper pipes, dim brick walls, orange molten channels far in the background. Detailed painterly hand-painted game art, matches dark medieval action RPG with readable silhouettes, rich charcoal plum, burnt copper and restrained amber lighting. Flat side view, deep atmospheric parallax planes, NO characters, NO text, NO UI, NO foreground gameplay platforms, NO foreground floor, NO huge bright focal flare. Bottom 35% mostly dark subdued distant architecture, top 20% very dark for HUD, warm glowing furnace windows only in middle-distance. This is background-only art behind separately drawn platforms.

## 角色图集提示词

参考图：`docs/chapter2_actions/ember_caster_actions_v2.png`、`forge_sentinel_actions_v1.png`、`ember_beetle_actions_v1.png`。

Create ONE production sprite atlas PNG with genuine transparent alpha background. Use the three attached images as character design references only; remove their grey backgrounds, labels and grid lines. EXACT 4 columns x 4 rows regular grid on a square 1536x1536 canvas. Each 384x384 cell has generous 30px empty transparent margins, every character entirely inside its cell, no overlapping cells. All characters face RIGHT in side / slight three-quarter side view, identical scale within each row, feet baseline y=344 within each cell. Columns in order: idle ready, attack windup with raised weapon/glowing core, attack action forward, collapsed defeated on ground. Row 1: ember caster from reference 1, charcoal armor red torn cloth orange furnace gauntlet and glowing chest. Row 2: forge sentinel from reference 2, enormous rectangular iron shield and hammer, ember cage chest. Row 3: ember beetle from reference 3, low black rocky insect with 6 legs and orange lava cracks. Row 4: a distinct towering forge overseer boss sharing art style, pale bronze crown exhaust vents, wide heavy pauldrons, circular white-hot chest, massive hammer arm, red cloth, NO shield, larger silhouette. Hand painted dark fantasy game art, crisp readable contour at small size, moderate simplified detailing, warm rims. No text, no numbers, no panels, no checkerboard, no ground shadows, no background, no isolated floating particles outside body. TRUE transparent background. Atlas intended for runtime 2D game sprites; exactly 16 separated figures.

## 冷却庭背景提示词

Production 2D side-scrolling dark fantasy action game background art, wide landscape 1536x1024. A tranquil cooling courtyard inside an ancient gothic iron foundry. Deep blue slate stone arches, oxidized copper pipes, huge distant water cisterns, gentle teal reflected light, distant red furnace glow through a small arch. Detailed painterly medieval fantasy environment, hand painted high quality, side-view camera. No people, no monsters, no text, no UI, no foreground gameplay platforms or floor. Background only, bottom 35% very subdued, top 20% dark for HUD. Middle-distance vertical architectural columns, layered depth and faint mist. Restrained luminance so bright character sprites and danger warnings remain readable.
