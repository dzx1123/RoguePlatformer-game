# 资源目录

运行时资源按用途放置：

- `characters/`：主角概念图、关键姿势和 `frames_polished/` 运行帧。
- `enemies/`：史莱姆、哥布林、首领和步行动画图集。
- `backgrounds/`：标题与战斗场景背景。
- `ui/`：图标和 UI 图形资源。
- `shaders/`：资源侧着色器与材质。
- `audio/designed/`：本项目原创合成语音与音效。
- `audio/music/`：本项目原创合成循环音乐。
- `audio/*_cc0/`：已在 `audio/LICENSES.md` 登记来源的 CC0 辅助层。

## 规则

- 新资源必须有明确授权；第三方资源同步更新 `audio/LICENSES.md` 或对应许可证文件。
- 角色帧遵守 `docs/CHARACTER_ANIMATION_SPEC.md`，先通过尺寸、Alpha 和锚点审计再接入。
- 像素资源保持 nearest 过滤，避免白底/JPEG 中转和带颜色的透明边。
- 生成源、色键中间图和工具输入不得直接作为运行时资源引用。
- 可复现生成工具位于 `tools/`；修改生成结果时同时保留稳定输入和验证步骤。
- 文档视觉稿位于 `docs/ui_mockups/`，不属于运行时资源。

音频来源、原创说明和再生成命令见 `assets/audio/LICENSES.md`。
