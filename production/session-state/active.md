# Session State

## Current Task
Production — 标题页、装备管理、视觉规格收尾完成，已通过 Godot 4.6 headless 验证

## Status
- [x] 主架构文档: docs/architecture/architecture.md
- [x] 正式项目搭建: src/
- [x] 测试运行 (Godot 4.6 headless)
- [x] 迭代优化：标题页、装备背包、视觉尺寸常量、验证脚本
- [ ] 手动体验回归

## Files Created (this session)
- src/project.godot — 项目配置
- src/scenes/Main.tscn — 主场景
- src/scenes/Enemy.tscn — 敌人场景
- src/scenes/TitleScreen.tscn — 标题场景
- src/scripts/game_manager.gd — 全局状态机 (Autoload)
- src/scripts/player.gd — 玩家移动 + 射击
- src/scripts/bullet_pool.gd — 子弹对象池 (250 发)
- src/scripts/bullet.gd — 子弹视觉
- src/scripts/enemy.gd — 敌人 AI (追击型)
- src/scripts/main.gd — 主场景逻辑 + HUD
- src/scripts/title_screen.gd — 标题页逻辑
- src/scripts/equipment_panel.gd — 装备槽与背包管理
- src/scripts/visual_spec.gd — 视觉尺寸常量
- ASSET_SPEC.md — 视觉素材规格

## Key Decisions
- 枪射击模式: 0.1s CD, 10 伤害, 单发
- 子弹池: 150 玩家 + 100 敌人
- 敌人: 追击型, 20 HP, 80px/s
- 首批生成 10 个敌人, 1s 间隔
- 主入口改为 TitleScreen，进入后到 Lobby
- 大厅装备管理使用 B 打开/关闭，装备槽状态保存在 GameManager.player_data
- 地牢内临时武器在返回大厅时恢复为大厅装备配置
- 视觉尺寸统一从 src/scripts/visual_spec.gd 读取

## Next
1. 用 Godot 4.6 打开 src/ 文件夹
2. 按 F5 运行
3. 标题页：Enter/Space/点击开始进入大厅
4. 大厅：WASD 移动，E 打开地图选择，B 打开/关闭背包，NPC 交互打开商店/天赋
5. 地牢：选择初始武器，清房间，Boss 后通过传送门返回大厅
6. 观察 FPS、子弹数、装备槽与返回大厅后的武器恢复是否符合预期
