# Rogue Platformer

这是一个原创 2D 横版动作肉鸽原型，使用 Godot 4 制作。第一版先验证最核心的手感：移动、跳跃、二段跳、冲刺、攻击与平台碰撞。

当前项目没有使用《死亡细胞》或任何其他商业游戏的角色、地图、音乐、美术或代码；临时画面都由项目代码直接绘制。

## 打开项目

1. 从 Godot 官方网站下载并解压 Godot 4 稳定版。
2. 将整个 RoguePlatformer 文件夹复制到 D:\RoguePlatformer。
3. 打开 Godot，点击 Import，选择 D:\RoguePlatformer\project.godot。
4. 在编辑器中按 F6 或 F5 运行。

Godot 官方下载页：

https://godotengine.org/download/windows/

## 操作

- A / D 或方向键左 / 右：移动
- W / 上方向键 / 空格：跳跃；离地后可再跳一次
- J：攻击测试动作
- K：冲刺
- R：回到出生点

## 项目结构

- scenes/：Godot 场景
- scripts/：游戏逻辑
- assets/：未来放入原创美术与音频
- docs/：功能路线

## Git

项目已经包含 .gitignore 和 .gitattributes，但尚未初始化 Git 仓库。准备上传时，在项目根目录执行：

    git init
    git add .
    git commit -m "chore: initialize roguelite prototype"

之后再添加你自己的远程仓库即可。
