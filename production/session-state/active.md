# Session State

## Current Task
Production — 正式项目搭建完成，待测试

## Status
- [x] 主架构文档: docs/architecture/architecture.md
- [x] 正式项目搭建: src/
- [ ] 测试运行 (Godot 4.6)
- [ ] 迭代优化

## Files Created (this session)
- src/project.godot — 项目配置
- src/scenes/Main.tscn — 主场景
- src/scenes/Enemy.tscn — 敌人场景
- src/scripts/game_manager.gd — 全局状态机 (Autoload)
- src/scripts/player.gd — 玩家移动 + 射击
- src/scripts/bullet_pool.gd — 子弹对象池 (250 发)
- src/scripts/bullet.gd — 子弹视觉
- src/scripts/enemy.gd — 敌人 AI (追击型)
- src/scripts/main.gd — 主场景逻辑 + HUD

## Key Decisions
- 枪射击模式: 0.1s CD, 10 伤害, 单发
- 子弹池: 150 玩家 + 100 敌人
- 敌人: 追击型, 20 HP, 80px/s
- 首批生成 10 个敌人, 1s 间隔

## Next
1. 用 Godot 4.6 打开 src/ 文件夹
2. 按 F5 运行
3. 测试: WASD 移动, 鼠标瞄准, 左键射击
4. 观察 FPS 和子弹数
