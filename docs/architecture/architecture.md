# 弹幕骑士 — 主架构文档

## 文档状态

| 字段 | 值 |
|------|-----|
| **版本** | 1 |
| **最后更新** | 2026-05-07 |
| **引擎** | Godot 4.6 |
| **语言** | GDScript |
| **渲染器** | gl_compatibility (Web) |
| **GDD 覆盖** | 15 个 MVP 系统 |
| **ADR 引用** | 无（待创建） |
| **技术总监签收** | 2026-05-07 — APPROVED |
| **主程序可行性** | LP-FEASIBILITY 跳过 (Lean 模式) |

---

## 引擎知识缺口摘要

**引擎**: Godot 4.6 | **LLM 训练覆盖**: 约至 4.3 | **风险等级**: HIGH（版本超出训练数据）

### 高风险领域

| 领域 | 关键变更 | 本项目影响 |
|------|---------|-----------|
| 物理引擎 | Jolt 成为默认 3D 物理 | **无影响** — 项目使用 Godot Physics 2D |
| 渲染 | Glow 重写、D3D12 默认 | **无影响** — 使用 gl_compatibility 渲染器 |
| 脚本语言 | @abstract、可变参数 | **低风险** — MVP 不使用这些特性 |

### 中风险领域

| 领域 | 关键变更 | 本项目影响 |
|------|---------|-----------|
| 着色器 | SMAA、纹理类型变更 | **低风险** — 像素风不依赖高级着色器 |
| 文件 I/O | FileAccess 返回 bool | **需注意** — 存档代码需用新 API |

### 结论

本项目作为 2D 像素风 Web 游戏，所有 15 个 MVP 系统均处于引擎低风险领域。高风险变更（Jolt、D3D12）仅影响 3D 项目。

---

## 系统层级图

```
┌─────────────────────────────────────────────────────────────────┐
│  表现层 (Presentation)                                           │
│  摄像机系统 | 打击反馈 | UI/HUD                                   │
├─────────────────────────────────────────────────────────────────┤
│  功能层 (Feature)                                                │
│  敌人AI | 关卡系统 | 房间战斗 | Boss战斗 | 复活系统               │
├─────────────────────────────────────────────────────────────────┤
│  核心层 (Core)                                                   │
│  生命值系统 | 玩家移动 | 瞄准系统 | 射击系统 | 弹道系统           │
├─────────────────────────────────────────────────────────────────┤
│  基础层 (Foundation)                                             │
│  游戏状态管理 | 碰撞检测                                          │
├─────────────────────────────────────────────────────────────────┤
│  平台层 (Platform)                                               │
│  Godot 4.6 引擎 | Web 导出                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 模块所有权

### 基础层 (Foundation)

#### 游戏状态管理 (GameManager)

| 维度 | 内容 |
|------|------|
| **Owns** | 全局状态机 (`_state: GameState`)、状态转换防抖 (`_state_debounce: float`)、暂停期间 `Engine.time_scale` 控制、关卡进度 (`current_floor`, `current_room`, `total_kills`)、新局初始化逻辑 |
| **Exposes** | `state` (只读属性)、`change_state(new_state)` 方法、`state_changed` 信号、`restart_game()` 方法 |
| **Consumes** | 无（基础层，无外部依赖） |
| **Engine APIs** | `Engine.time_scale`、`SceneTree.paused`、`get_tree().reload_current_scene()` |

#### 碰撞检测 (CollisionManager)

| 维度 | 内容 |
|------|------|
| **Owns** | 6 层碰撞层配置 (`collision_layer`/`collision_mask` 位掩码)、碰撞形状资源 (`CircleShape2D`, `RectangleShape2D`)、碰撞信号路由表 |
| **Exposes** | `get_layer_mask(layers: Array[Layer]) -> int` 工具方法、5 个碰撞信号 |
| **Consumes** | 无（纯配置+信号转发） |
| **Engine APIs** | `Area2D`、`StaticBody2D`、`CollisionShape2D`、`body_entered`/`area_entered` 信号 |

**碰撞信号表**:

| 信号 | 发射者 | 接收者 |
|------|--------|--------|
| `player_bullet_hit_enemy(bullet, enemy)` | PLAYER_BULLET Area2D | HealthSystem |
| `enemy_bullet_hit_player(bullet, player)` | ENEMY_BULLET Area2D | HealthSystem |
| `enemy_touch_player(enemy, player)` | ENEMY Area2D | HealthSystem |
| `bullet_hit_wall(bullet, wall)` | Any Bullet Area2D | ProjectileSystem |
| `player_pickup(player, pickup)` | PLAYER Area2D | ReviveSystem |

### 核心层 (Core)

#### 生命值系统 (HealthSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | HP 数据 (`max_hp`, `current_hp`, `armor`)、无敌帧状态机 (`_invincible: bool`, `_invincible_timer: float`)、伤害计算公式、死亡判定逻辑 |
| **Exposes** | `take_damage(target, amount)`, `heal(target, amount)`, `is_alive(node)`, `get_hp_ratio(node)` 查询方法 |
| **Consumes** | GameManager 状态（PAUSED/DEAD 不处理伤害）、CollisionManager 碰撞信号 |
| **Engine APIs** | `Node2D.modulate` (无敌闪烁)、`Timer` (无敌帧计时) |
| **Signals** | `player_died`, `enemy_died(enemy)`, `boss_died(boss)`, `health_changed(entity, current, max)`, `damage_dealt(target, amount, position)` |

#### 瞄准系统 (AimingSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | 瞄准方向 (`_aim_direction: Vector2`)、锁定瞄准状态 (`_lock_target: Node2D`, `_lock_range: float`) |
| **Exposes** | `get_aim_direction() -> Vector2` (只读，每帧更新) |
| **Consumes** | GameManager 状态（仅 PLAYING 激活）、玩家节点位置 |
| **Engine APIs** | `get_global_mouse_position()`、`InputEventMouseMotion` |

#### 射击系统 (ShootingSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | 武器数据表 (Bow/Staff/Gun)、当前武器状态 (`_current_weapon`, `_cooldown_timer`)、射击状态机 (READY/COOLDOWN/DISABLED) |
| **Exposes** | `shoot(shooter, weapon_type) -> bool`, `switch_weapon(type)`, `get_current_weapon() -> WeaponData` |
| **Consumes** | AimingSystem 方向、ProjectileSystem 发射接口、HealthSystem 伤害属性 |
| **Engine APIs** | `Timer` (冷却控制) |
| **Signals** | `weapon_fired(weapon_type, position, direction)`, `weapon_switched(old_type, new_type)` |

#### 弹道系统 (ProjectileSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | 对象池 (`_player_pool: Array[Node2D]`, `_enemy_pool: Array[Node2D]`)、池大小配置 (150+100)、活跃子弹计数、子弹生命周期管理 |
| **Exposes** | `spawn_bullet(config: BulletConfig) -> bool`, `deactivate_bullet(bullet)`, `get_active_count() -> int`, `clear_all()` |
| **Consumes** | CollisionManager 碰撞信号 (`bullet_hit_wall`) |
| **Engine APIs** | `Area2D` (子弹节点)、`_physics_process` (移动)、`Node2D.visible`/`monitoring` (池化切换) |
| **Signals** | `bullet_hit(bullet, target, damage)` |

### 功能层 (Feature)

#### 敌人 AI (EnemyAI)

| 维度 | 内容 |
|------|------|
| **Owns** | 4 种行为模式配置 (CHASER/SHOOTER/TANK/SWARM)、AI 状态机 (IDLE/CHASE/ATTACK/DEAD)、生成配置 |
| **Exposes** | `spawn_enemy(type, position) -> Node2D`, `get_enemies() -> Array[Node2D]`, `get_alive_count() -> int` |
| **Consumes** | HealthSystem 敌人 HP、CollisionManager 碰撞层设置 |
| **Engine APIs** | `CharacterBody2D.move_and_slide()` (敌人移动) |
| **Signals** | `all_enemies_died` |

#### 关卡系统 (LevelSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | 楼层结构数据 (1-1/1-2/1-3/1-4/1-5)、当前进度 (`_current_floor`, `_current_room_index`)、难度递增参数 (+15% HP/+20% count) |
| **Exposes** | `get_current_room_config() -> RoomConfig`, `advance_room()`, `get_floor_progress() -> float` |
| **Consumes** | GameManager 状态 |
| **Engine APIs** | 无直接引擎 API（纯数据管理） |
| **Signals** | `floor_completed(floor)`, `game_victory` |

#### 房间战斗 (RoomCombat)

| 维度 | 内容 |
|------|------|
| **Owns** | 房间状态机 (EMPTY/FIGHTING/CLEARED)、门状态 (开/关)、房间尺寸 (960x640)、模板系统 |
| **Exposes** | `enter_room(room_config)`, `is_room_cleared() -> bool`, `get_door_state() -> bool` |
| **Consumes** | LevelSystem 房间配置、EnemyAI 敌人生成、GameManager 状态 |
| **Engine APIs** | `StaticBody2D` (门碰撞)、`CollisionShape2D.disabled` (开关门) |
| **Signals** | `room_entered`, `room_cleared`, `doors_opened` |

#### Boss 战斗 (BossBattle)

| 维度 | 内容 |
|------|------|
| **Owns** | Boss 血量 (500 HP)、3 阶段状态机 (Phase 1/2/3)、攻击模式 (扇形/环形/冲刺)、阶段切换阈值 |
| **Exposes** | `spawn_boss(position) -> Node2D`, `get_boss_phase() -> int`, `is_boss_alive() -> bool` |
| **Consumes** | EnemyAI 基础行为、HealthSystem 血量管理、LevelSystem Boss 房间配置 |
| **Engine APIs** | `CharacterBody2D` (Boss 节点) |
| **Signals** | `boss_phase_changed(old_phase, new_phase)`, `boss_spawned`, `boss_died` |

#### 复活系统 (ReviveSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | 复活币数量 (`_coins: int`)、倒计时 (`_countdown: float`)、去色/恢复状态 |
| **Exposes** | `has_coin() -> bool`, `revive()`, `start_revive流程()`, `get_countdown() -> float` |
| **Consumes** | HealthSystem 玩家死亡信号、GameManager 状态转换 |
| **Engine APIs** | `ShaderMaterial` (去色)、`Timer` (倒计时) |
| **Signals** | `revive_started`, `revive_completed`, `revive_expired` |

### 表现层 (Presentation)

#### 摄像机系统 (CameraSystem)

| 维度 | 内容 |
|------|------|
| **Owns** | Camera2D 节点、震动队列 (`_shake_queue: Array[ShakeEvent]`)、震动叠加逻辑、房间边界约束 |
| **Exposes** | `trigger_shake(intensity, duration, decay_type)`, `set_room_bounds(rect: Rect2)`, `boss_zoom_in()`, `boss_zoom_out()` |
| **Consumes** | 玩家节点位置（跟随）、RoomCombat 房间边界 |
| **Engine APIs** | `Camera2D`、`position_smoothing_speed`、`zoom`、`offset` |
| **Signals** | `shake_started`, `shake_ended` |

#### 打击反馈 (HitFeedback)

| 维度 | 内容 |
|------|------|
| **Owns** | Hit stop 状态机、飘字对象池 (max 20)、闪白时序、击杀特效序列 |
| **Exposes** | `on_hit(target, damage, position)`, `on_kill(target, position)`, `on_player_hurt(damage)` |
| **Consumes** | HealthSystem 伤害/死亡信号、ShootingSystem 命中信号、CameraSystem 震动触发 |
| **Engine APIs** | `Engine.time_scale` (hit stop)、`Label` (飘字)、`Node2D.modulate` (闪白) |
| **Signals** | `hit_stop_started`, `hit_stop_ended` |

#### UI/HUD (UIManager)

| 维度 | 内容 |
|------|------|
| **Owns** | CanvasLayer 层级 (0/10/20/30/40/50)、所有 UI 面板引用、血条更新逻辑 |
| **Exposes** | `show_hud()`, `hide_hud()`, `show_revive_ui(countdown)`, `show_pause_menu()`, `show_game_over(kills)` |
| **Consumes** | HealthSystem HP 数据、BossBattle Boss 血量、ReviveSystem 复活状态、GameManager 状态切换 |
| **Engine APIs** | `CanvasLayer`、`TextureProgressBar`、`Control`、`Tween` |

### 模块依赖关系图

```
                    ┌─────────────────────────────────────────┐
                    │          基础层 (Foundation)              │
                    │                                         │
                    │  ┌──────────────┐  ┌──────────────────┐ │
                    │  │ GameManager  │  │ CollisionManager │ │
                    │  │ (状态机)      │  │ (碰撞层配置)      │ │
                    │  └──────┬───────┘  └────┬──┬──┬───────┘ │
                    └─────────┼───────────────┼──┼──┼─────────┘
                              │               │  │  │
            ┌─────────────────┼───────────────┼──┼──┼────────────────────┐
            │                 │               │  │  │    核心层 (Core)   │
            │                 ▼               ▼  │  │                    │
            │  ┌──────────────────┐  ┌─────────┴──┴──┐                  │
            │  │  AimingSystem    │  │ HealthSystem   │                  │
            │  │  (鼠标→方向)      │  │ (HP/伤害/死亡) │                  │
            │  └────────┬─────────┘  └───┬───┬───┬───┘                  │
            └───────────┼────────────────┼───┼───┼──────────────────────┘
                        │                │   │   │
       ┌────────────────┼────────────────┼───┼───┼──────────────────────┐
       │                │                │   │   │   功能层 (Feature)   │
       │                ▼                ▼   │   │                      │
       │  ┌───────────────────┐ ┌───────────┴───┴───┐                  │
       │  │  ShootingSystem   │ │    EnemyAI        │ ┌──────────────┐ │
       │  │  (武器/射击控制)   │ │ (4种敌人行为)     │ │ LevelSystem  │ │
       │  └────────┬──────────┘ └────────┬──────────┘ │ (楼层/房间)   │ │
       │           │                     │            └───────┬──────┘ │
       │           ▼                     │                    │        │
       │  ┌──────────────────┐           │                    ▼        │
       │  │ ProjectileSystem │           │          ┌────────────────┐ │
       │  │ (子弹对象池)      │           │          │  RoomCombat    │ │
       │  └──────────────────┘           │          │ (房间生命周期)  │ │
       │                                 │          └────────┬───────┘ │
       │           ┌─────────────────────┘                   │         │
       │           │     ┌────────────────────┐              │         │
       │           │     │    BossBattle      │◄─────────────┘         │
       │           │     │ (Boss AI+血量)     │                        │
       │           │     └────────┬───────────┘                        │
       │           │              │                                    │
       │           ▼              ▼                                    │
       │  ┌──────────────────────────┐  ┌────────────────┐            │
       │  │     ReviveSystem         │  │                │            │
       │  │  (复活币/倒计时/去色)     │  │                │            │
       │  └──────────────────────────┘  │                │            │
       └────────────────────────────────┼────────────────┼────────────┘
                                        │                │
            ┌───────────────────────────┼────────────────┼─────────────┐
            │                           │                │  表现层      │
            │                           ▼                ▼             │
            │           ┌───────────────────┐  ┌──────────────────┐   │
            │           │   CameraSystem    │  │   UIManager      │   │
            │           │ (跟随/震动/缩放)   │  │ (血条/菜单/HUD)  │   │
            │           └─────────┬─────────┘  └──────────────────┘   │
            │                     ▼                                    │
            │           ┌───────────────────┐                         │
            │           │  HitFeedback      │                         │
            │           │ (hitstop/闪白/飘字)│                         │
            │           └───────────────────┘                         │
            └─────────────────────────────────────────────────────────┘
```

---

## 数据流

### 帧更新路径

每帧数据从输入层流经核心系统、到状态更新、最终到渲染输出：

```
输入层              核心层                    功能层              表现层
─────              ─────                    ─────              ─────
Input.is_action  → AimingSystem.get_aim()  → ShootingSystem
_pressed()            │                         │
                      │ direction               │ BulletConfig
                      ▼                         ▼
Input.get_axis() → PlayerMovement         → ProjectileSystem.move()
(move_left/right)    │ velocity                 │ position
                     │                          │ collision check
                     ▼                          ▼
                 CharacterBody2D           CollisionManager
                 .move_and_slide()          .check_collisions()
                                              │ signals
                                              ▼
                                         HealthSystem.take_damage()
                                              │ hp_changed
                                              ▼
                                         HitFeedback.on_hit()  → CameraSystem.trigger_shake()
                                         UIManager.update_hp() → 所有 UI 刷新
```

**详细帧时序** (每帧 `_physics_process`):

```
1. Input 轮询
   ├── GameManager.state != PLAYING → 跳过步骤 2-6
   ├── Input.is_action_just_pressed("shoot") → ShootingSystem.shoot()
   └── Input.get_axis("move_left", "move_right") → 位移向量

2. 瞄准计算 (AimingSystem._physics_process)
   ├── _aim_direction = (get_global_mouse_position() - player.global_position).normalized()
   └── 更新锁定目标 (如果激活)

3. 物理运动 (CharacterBody2D._physics_process)
   ├── PlayerMovement.move_and_slide()
   ├── EnemyAI 所有敌人 move_and_slide()
   └── ProjectileSystem 所有活跃子弹 position += direction * speed * delta

4. 碰撞检测 (Godot Physics2D 自动执行)
   ├── Area2D.area_entered / body_entered 触发
   ├── CollisionManager 路由信号
   └── HealthSystem 接收信号 → take_damage()

5. 状态更新
   ├── HealthSystem: 检查死亡 → player_died / enemy_died 信号
   ├── RoomCombat: 检查 all_enemies_died → room_cleared
   ├── LevelSystem: 检查 floor_completed / game_victory
   └── ReviveSystem: 检查倒计时

6. 表现刷新 (_process)
   ├── HitFeedback: 更新飘字位置、hit stop 恢复
   ├── CameraSystem: 更新震动 offset、zoom 插值
   ├── UIManager: 更新血条、Boss 血条、倒计时数字
   └── 所有 Sprite.modulate 闪烁状态更新
```

### 事件/信号路径

信号是模块间通信的主要机制。

#### 场景 A：玩家子弹命中敌人

```
Area2D (PLAYER_BULLET).area_entered
    │
    ├──► CollisionManager: 路由 player_bullet_hit_enemy(bullet, enemy)
    │        │
    │        ├──► HealthSystem.take_damage(enemy, bullet.damage)
    │        │        │
    │        │        ├──► Signal: damage_dealt(enemy, damage, position)
    │        │        │        │
    │        │        │        ├──► HitFeedback.on_hit(enemy, damage, position)
    │        │        │        │        ├── 闪白 1 帧
    │        │        │        │        ├── 生成飘字 Label
    │        │        │        │        └── 触发 CameraSystem.trigger_shake(2.0, 0.1s)
    │        │        │        │
    │        │        │        └──► UIManager: 血条即时更新
    │        │        │
    │        │        └──► (如果死亡) Signal: enemy_died(enemy)
    │        │                 │
    │        │                 ├──► HitFeedback.on_kill(enemy, position)
    │        │                 │        ├── 击杀闪烁 3 次
    │        │                 │        ├── 缩小消失 0.2s
    │        │                 │        └── CameraSystem.trigger_shake(1.0, 0.05s)
    │        │                 │
    │        │                 └──► EnemyAI: 检查 get_alive_count() == 0
    │        │                          │
    │        │                          └──► Signal: all_enemies_died
    │        │                                   │
    │        │                                   └──► RoomCombat: 状态 → CLEARED
    │        │                                            │
    │        │                                            ├── 0.5s 延迟
    │        │                                            └── Signal: doors_opened
    │        │
    │        └──► ProjectileSystem.deactivate_bullet(bullet)
    │                 (除非 pierce > 0)
    │
    └──► 碰撞信号完成
```

#### 场景 B：敌人子弹命中玩家

```
Area2D (ENEMY_BULLET).area_entered
    │
    └──► CollisionManager: enemy_bullet_hit_player(bullet, player)
             │
             └──► HealthSystem.take_damage(player, bullet.damage)
                      │
                      ├── (invincible == true) → 忽略
                      │
                      └── (invincible == false)
                           │
                           ├── current_hp -= damage
                           ├── invincible = true, timer = 1.5s
                           │
                           ├──► Signal: health_changed(player, hp, max_hp)
                           │        └──► UIManager: 血条更新
                           │
                           ├──► HitFeedback.on_player_hurt(damage)
                           │        ├── CameraSystem.trigger_shake(4.0, 0.15s)
                           │        └── 玩家闪红
                           │
                           └──► (如果 hp <= 0) Signal: player_died
                                    │
                                    ├──► GameManager: change_state(DEAD)
                                    │        ├── Engine.time_scale = 0
                                    │        └── 屏幕去色
                                    │
                                    └──► ReviveSystem.start_revive流程()
                                             │
                                             ├── (有复活币) → DEAD → REVIVING
                                             │        └── 10s 倒计时
                                             │
                                             └── (无复活币) → DEAD → GAME_OVER
```

#### 场景 C：房间切换

```
RoomCombat: room_cleared
    │
    ├── 0.5s 延迟
    ├── Signal: doors_opened
    │
    └── (玩家接触门) Area2D.room_enter 触发
         │
         ├──► RoomCombat.enter_room(next_room_config)
         │        ├── 清除所有活跃子弹 (ProjectileSystem.clear_all())
         │        ├── 重置门状态 → 关闭
         │        ├── 重置房间状态 → FIGHTING
         │        ├── 重置玩家位置到入口
         │        └── CameraSystem.set_room_bounds(new_room_rect)
         │
         ├──► LevelSystem.advance_room()
         │        ├── current_room_index += 1
         │        └── (如果是 Boss 房间) Signal: boss_room_entered
         │
         └──► EnemyAI.spawn_enemy() × N (按配置逐个生成)
```

#### 场景 D：Boss 阶段切换

```
HealthSystem: damage_dealt(boss, damage)
    │
    └──► BossBattle: 检查 hp_ratio
             │
             ├── (hp <= 60% && current_phase < 2)
             │        ├── current_phase = 2
             │        ├── Signal: boss_phase_changed(1, 2)
             │        ├── 短暂无敌 (阶段切换保护)
             │        └── CameraSystem.trigger_shake(5.0, 0.2s)
             │
             └── (hp <= 30% && current_phase < 3)
                      ├── current_phase = 3
                      ├── Signal: boss_phase_changed(2, 3)
                      ├── 短暂无敌
                      └── CameraSystem.trigger_shake(5.0, 0.2s)
```

### 存档/加载路径

MVP 阶段仅保存最基本的进度数据：

| 数据 | 类型 | 存储位置 | 何时写入 | 何时读取 |
|------|------|----------|----------|----------|
| `current_floor` | int | `user://save.json` | 房间切换时 | 游戏启动时 |
| `current_room_index` | int | `user://save.json` | 房间切换时 | 游戏启动时 |
| `total_kills` | int | `user://save.json` | 每次击杀时 | 游戏结束时 |
| `weapons_unlocked` | Array | `user://save.json` | 解锁武器时 | 游戏启动时 |
| `settings` | Dictionary | `user://settings.json` | 设置变更时 | 游戏启动时 |

**不保存的数据** (Roguelike 设计 — 死亡即清除):
- 玩家当前 HP/护甲
- 强化/升级状态
- 房间内敌人配置

**序列化格式**:

```json
{
  "version": 1,
  "progress": {
    "current_floor": 1,
    "current_room_index": 0,
    "total_kills": 47,
    "weapons_unlocked": ["bow", "staff"]
  }
}
```

### 初始化顺序

```
游戏启动
    │
    ├──► 1. 加载项目设置 (project.godot)
    │        ├── 输入映射 (WASD, 鼠标, ESC)
    │        ├── 碰撞层配置 (6 层)
    │        └── 窗口设置 (分辨率, 标题)
    │
    ├──► 2. 加载 Autoload 单例 (按依赖顺序)
    │        ├── 2a. GameManager._ready()  ← 最先，无依赖
    │        ├── 2b. CollisionManager._ready()  ← 无依赖
    │        ├── 2c. ProjectileSystem._ready()  ← 预分配对象池
    │        └── 2d. UIManager._ready()  ← CanvasLayer 初始化
    │
    ├──► 3. 加载主场景 (Main.tscn)
    │        ├── 3a. World._ready()
    │        │        ├── 实例化 Player (CharacterBody2D)
    │        │        ├── 实例化 Camera2D (CameraSystem)
    │        │        ├── 实例化 Room (静态体+门)
    │        │        └── HealthSystem.init_player_hp()
    │        │
    │        ├── 3b. LevelSystem._ready()
    │        │        ├── 加载楼层配置
    │        │        └── 设置当前房间
    │        │
    │        ├── 3c. RoomCombat._ready()
    │        │        ├── 连接信号
    │        │        └── 进入第一个房间
    │        │
    │        └── 3d. 连接跨系统信号
    │                 ├── CollisionManager.player_bullet_hit_enemy → HealthSystem
    │                 ├── CollisionManager.enemy_bullet_hit_player → HealthSystem
    │                 ├── HealthSystem.damage_dealt → HitFeedback
    │                 ├── HealthSystem.player_died → GameManager + ReviveSystem
    │                 ├── EnemyAI.all_enemies_died → RoomCombat
    │                 └── LevelSystem.game_victory → GameManager
    │
    ├──► 4. GameManager.change_state(MAIN_MENU)
    │        ├── Engine.time_scale = 1.0
    │        ├── UIManager.show_main_menu()
    │        └── Signal: state_changed(MAIN_MENU)
    │
    └──► 5. 游戏就绪，等待玩家输入
```

**新局重启流程**:

```
GameManager.restart_game()
    │
    ├── Engine.time_scale = 1.0
    ├── 重置 current_floor = 1, current_room_index = 0
    ├── 重置 total_kills = 0
    ├── ProjectileSystem.clear_all()  ← 清除所有子弹
    ├── HealthSystem.init_player_hp()  ← 恢复满血
    ├── ReviveSystem.reset_coins()  ← 重置复活币
    ├── LevelSystem.load_floor(1)  ← 加载第一层
    ├── RoomCombat.enter_room(first_room)  ← 进入第一个房间
    ├── CameraSystem.set_room_bounds(first_room_bounds)
    ├── UIManager.show_hud()
    └── change_state(PLAYING)
```

---

## API 边界

### GameManager

```gdscript
class_name GameManager
extends Node

enum GameState { MAIN_MENU, PLAYING, PAUSED, DEAD, REVIVING, GAME_OVER }

signal state_changed(old_state: GameState, new_state: GameState)
signal game_restarted

var state: GameState:
    get: return _state

func change_state(new_state: GameState) -> void
func restart_game() -> void
func add_kill() -> void
func get_kill_count() -> int
```

### CollisionManager

```gdscript
class_name CollisionManager
extends Node

enum Layer { PLAYER=0, ENEMY=1, PLAYER_BULLET=2, ENEMY_BULLET=3, WALL=4, PICKUP=5 }

signal player_bullet_hit_enemy(bullet: Area2D, enemy: Area2D)
signal enemy_bullet_hit_player(bullet: Area2D, player: Area2D)
signal enemy_touch_player(enemy: Area2D, player: Area2D)
signal bullet_hit_wall(bullet: Area2D, wall: Node2D)
signal player_pickup(player: Area2D, pickup: Area2D)

static func get_layer_mask(layers: Array[Layer]) -> int
static func get_layer_bit(layer: Layer) -> int
```

### HealthSystem

```gdscript
class_name HealthSystem
extends Node

signal health_changed(entity: Node2D, current_hp: int, max_hp: int)
signal damage_dealt(target: Node2D, amount: int, position: Vector2)
signal player_died
signal enemy_died(enemy: Node2D)
signal boss_died(boss: Node2D)
signal healed(entity: Node2D, amount: int)

func register(entity: Node2D, max_hp: int, armor: int = 0, invincible_duration: float = 0.0) -> void
func take_damage(target: Node2D, base_damage: int) -> int
func heal(entity: Node2D, amount: int) -> void
func is_alive(entity: Node2D) -> bool
func get_hp_ratio(entity: Node2D) -> float
func get_hp(entity: Node2D) -> int
func is_invincible(entity: Node2D) -> bool
```

### AimingSystem

```gdscript
class_name AimingSystem
extends Node

signal aim_direction_changed(direction: Vector2)
signal lock_on_target_acquired(target: Node2D)
signal lock_on_target_lost

func get_aim_direction() -> Vector2
func get_aim_angle() -> float
func get_lock_target() -> Node2D
func activate() -> void
func deactivate() -> void
```

### ShootingSystem

```gdscript
class_name ShootingSystem
extends Node

signal weapon_fired(weapon_type: StringName, position: Vector2, direction: Vector2)
signal weapon_switched(old_weapon: StringName, new_weapon: StringName)

func shoot(shooter: Node2D, weapon_type: StringName = &"") -> bool
func switch_weapon(new_weapon: StringName) -> bool
func get_current_weapon() -> WeaponData
func get_weapon_data(type: StringName) -> WeaponData
func is_ready() -> bool
```

### ProjectileSystem

```gdscript
class_name ProjectileSystem
extends Node

signal bullet_hit(bullet: Area2D, target: Node2D, damage: int)
signal bullet_recycled(bullet: Area2D)

const PLAYER_POOL_SIZE := 150
const ENEMY_POOL_SIZE := 100
const TOTAL_MAX_ACTIVE := 250

func spawn_bullet(config: BulletConfig) -> bool
func deactivate_bullet(bullet: Area2D) -> void
func clear_all() -> void
func get_active_count() -> int
func get_player_bullet_count() -> int
func get_enemy_bullet_count() -> int
```

### EnemyAI

```gdscript
class_name EnemyAI
extends Node

enum EnemyType { CHASER, SHOOTER, TANK, SWARM }
enum AIState { IDLE, CHASE, ATTACK, DEAD }

signal all_enemies_died
signal enemy_spawned(enemy: Node2D)
signal enemy_removed(enemy: Node2D)

const CHASER_SPEED := 100.0
const SHOOTER_SPEED := 80.0
const TANK_SPEED := 50.0
const SWARM_SPEED := 120.0

func spawn_enemy(type: EnemyType, position: Vector2) -> Node2D
func spawn_wave(types: Array[EnemyType], positions: Array[Vector2]) -> void
func get_alive_count() -> int
func get_enemies() -> Array[Node2D]
func remove_enemy(enemy: Node2D) -> void
func stop_all() -> void
```

### LevelSystem

```gdscript
class_name LevelSystem
extends Node

signal floor_completed(floor: int)
signal game_victory
signal room_config_loaded(config: RoomConfig)

const HP_PER_FLOOR := 0.15
const COUNT_PER_FLOOR := 0.20
const WEAPON_UNLOCK_ROOMS := [&"1-3", &"1-5"]

func load_floor(floor_number: int) -> void
func get_current_room_config() -> RoomConfig
func advance_room() -> void
func get_floor_progress() -> float
func get_current_floor() -> int
func get_current_room_index() -> int
func is_boss_room() -> bool
func get_difficulty_multiplier() -> float
```

### RoomCombat

```gdscript
class_name RoomCombat
extends Node

enum RoomState { EMPTY, FIGHTING, CLEARED }

signal room_entered(room_index: int)
signal room_cleared(room_index: int)
signal doors_opened

func enter_room(config: LevelSystem.RoomConfig) -> void
func is_room_cleared() -> bool
func get_door_state() -> bool
func get_room_state() -> RoomState
func get_room_size() -> Vector2
```

### BossBattle

```gdscript
class_name BossBattle
extends Node

enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
enum BossAttack { FAN_BARRAGE, RING_BARRAGE, DASH }

const PHASE_2_THRESHOLD := 0.6
const PHASE_3_THRESHOLD := 0.3

signal boss_spawned(boss: Node2D)
signal boss_phase_changed(old_phase: BossPhase, new_phase: BossPhase)
signal boss_died(boss: Node2D)
signal boss_attack_started(attack: BossAttack)

func spawn_boss(position: Vector2) -> Node2D
func get_boss_phase() -> BossPhase
func is_boss_alive() -> bool
func get_boss_hp_ratio() -> float
func check_phase_transition() -> void
```

### ReviveSystem

```gdscript
class_name ReviveSystem
extends Node

signal revive_started(countdown: float)
signal revive_completed
signal revive_expired

const REVIVE_COUNTDOWN := 10.0
const REVIVE_HP_RATIO := 0.5
const REVIVE_INVINCIBLE_DURATION := 1.5

func has_coin() -> bool
func start_revive流程() -> void
func revive() -> void
func get_countdown() -> float
func reset_coins() -> void
```

### CameraSystem

```gdscript
class_name CameraSystem
extends Node

signal shake_started
signal shake_ended

const SHAKE_CONFIG := {
    "player_hit":   {"intensity": 2.0, "duration": 0.1,  "decay": "linear"},
    "player_hurt":  {"intensity": 4.0, "duration": 0.15, "decay": "linear"},
    "boss_hit":     {"intensity": 5.0, "duration": 0.2,  "decay": "linear"},
    "boss_death":   {"intensity": 8.0, "duration": 0.5,  "decay": "exponential"},
    "enemy_death":  {"intensity": 1.0, "duration": 0.05, "decay": "linear"},
}

func trigger_shake(intensity: float, duration: float, decay_type: StringName = &"linear") -> void
func set_room_bounds(rect: Rect2) -> void
func boss_zoom_in() -> void
func boss_zoom_out() -> void
func reset() -> void
```

### HitFeedback

```gdscript
class_name HitFeedback
extends Node

signal hit_stop_started(frames: int)
signal hit_stop_ended

const HIT_STOP_FRAMES := {
    "enemy_hit":  1,
    "boss_hit":   2,
    "enemy_kill": 3,
    "boss_kill":  5,
}

func on_hit(target: Node2D, damage: int, position: Vector2) -> void
func on_kill(target: Node2D, position: Vector2) -> void
func on_player_hurt(damage: int) -> void
func on_boss_hit(damage: int, position: Vector2) -> void
func on_boss_kill(position: Vector2) -> void
```

### UIManager

```gdscript
class_name UIManager
extends Node

const LAYER_GAME_WORLD := 0
const LAYER_HUD := 10
const LAYER_REVIVE := 20
const LAYER_PAUSE := 30
const LAYER_GAME_OVER := 40
const LAYER_MAIN_MENU := 50

func show_hud() -> void
func hide_hud() -> void
func update_player_hp(current: int, max_hp: int) -> void
func update_boss_hp(current: int, max_hp: int) -> void
func show_revive_ui(countdown: float, has_coin: bool) -> void
func update_revive_countdown(time_remaining: float) -> void
func hide_revive_ui() -> void
func show_pause_menu() -> void
func hide_pause_menu() -> void
func show_game_over(total_kills: int) -> void
func show_main_menu() -> void
func show_floor_transition(floor: int) -> void
```

---

## ADR 审计

`docs/architecture/` 目录为空 — 无现有 ADR 可审计。

---

## 所需 ADR 列表

### 必须在编码前完成（基础层 + 核心层）

| ADR | 覆盖需求 |
|-----|---------|
| 全局状态管理架构 | TR-game-state-001~004 |
| 碰撞层配置与信号路由 | TR-collision-001~003 |
| 子弹对象池与弹道系统 | TR-proj-001~005 |
| 伤害计算与生命值系统 | TR-health-001~004, TR-hit-001~004 |

### 应在相关系统构建前完成

| ADR | 覆盖需求 |
|-----|---------|
| 玩家移动与物理交互 | TR-move-001~005, TR-aim-001~004 |
| 武器系统与射击机制 | TR-shoot-001~004 |
| 敌人 AI 行为架构 | TR-enemy-001~005, TR-boss-001~005 |
| 关卡生成与房间管理 | TR-level-001~005, TR-room-001~004, TR-revive-001~004 |

### 可延迟到实现阶段

| ADR | 覆盖需求 |
|-----|---------|
| 摄像机跟随与震动系统 | TR-camera-001~004 |
| UI/HUD 层级架构 | TR-ui-001~005 |

---

## 架构原则

1. **信号驱动通信** — 模块间通过 Godot 信号松耦合，不直接引用对方实例
2. **对象池优先** — 所有频繁创建/销毁的对象（子弹、飘字、敌人）必须使用对象池
3. **状态机管理** — 游戏状态、房间状态、Boss 阶段、AI 状态均用有限状态机控制
4. **数据驱动配置** — 武器数据、敌人属性、难度参数从外部配置加载，不硬编码
5. **帧率无关** — 所有移动和计时使用 `delta` 时间，确保不同帧率下行为一致

---

## 开放问题

| 问题 | 状态 | 阻塞 |
|------|------|------|
| 具体武器解锁条件（击杀数 vs 房间号） | 待定 | 不阻塞 MVP |
| Boss 具体弹幕图案数值 | 待定 | 不阻塞 MVP |
| 楼层过渡动画细节 | 待定 | 不阻塞 MVP |
| 存档加密/防篡改 | 延后 | 不阻塞 MVP |
| 多人/排行榜 | 远期 | 不阻塞 MVP |
