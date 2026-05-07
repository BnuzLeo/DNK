# Systems Index: 弹幕骑士 (Bullet Knight)

> **Status**: Draft
> **Created**: 2026-05-07
> **Last Updated**: 2026-05-07 (游戏状态管理 designed)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

弹幕骑士是一款俯视角 Roguelike 弹幕射击游戏。核心循环是"移动 → 射击 → 击杀 → 清房 → 强化 → Boss → 下一层"。游戏需要 17 个系统来支撑这个循环，其中 15 个是 MVP 必需。系统设计以"弹幕爽感"和"即时反馈"两个支柱为核心，碰撞检测和生命值系统是最高瓶颈 — 所有战斗系统都依赖它们。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 游戏状态管理 | Core | MVP | **Designed** | design/gdd/game-state-management.md | — |
| 2 | 碰撞检测 | Core | MVP | **Designed** | design/gdd/collision-detection.md | — |
| 3 | 生命值系统 | Core | MVP | **Designed** | design/gdd/health-system.md | 游戏状态管理, 碰撞检测 |
| 4 | 瞄准系统 | Core | MVP | **Designed** | design/gdd/aiming-system.md | 游戏状态管理 |
| 5 | 玩家移动 | Gameplay | MVP | **Designed** | design/gdd/player-movement.md | 碰撞检测 |
| 6 | 弹道系统 | Gameplay | MVP | **Designed** | design/gdd/projectile-system.md | 碰撞检测 |
| 7 | 敌人 AI | Gameplay | MVP | **Designed** | design/gdd/enemy-ai.md | 生命值系统, 碰撞检测 |
| 8 | 关卡/楼层系统 | Gameplay | MVP | **Designed** | design/gdd/level-system.md | 游戏状态管理 |
| 9 | 射击系统 | Gameplay | MVP | **Designed** | design/gdd/shooting-system.md | 瞄准系统, 弹道系统, 碰撞检测, 生命值系统 |
| 10 | Boss 战 | Gameplay | MVP | **Designed** | design/gdd/boss-battle.md | 敌人 AI, 生命值系统, 关卡/楼层系统 |
| 11 | 房间制战斗 | Gameplay | MVP | **Designed** | design/gdd/room-combat.md | 关卡/楼层系统, 敌人 AI, 游戏状态管理 |
| 12 | 复活币系统 | Gameplay | MVP | **Designed** | design/gdd/revive-system.md | 生命值系统, 游戏状态管理 |
| 13 | 摄像机系统 | Presentation | MVP | **Designed** | design/gdd/camera-system.md | 玩家移动 |
| 14 | 打击反馈 | Presentation | MVP | **Designed** | design/gdd/hit-feedback.md | 射击系统, 生命值系统, 摄像机系统 |
| 15 | UI/HUD | Presentation | MVP | **Designed** | design/gdd/ui-hud.md | 生命值系统, Boss 战, 复活币系统, 游戏状态管理 |
| 16 | 近战攻击 | Gameplay | Vertical Slice | Not Started | — | 玩家移动, 碰撞检测, 生命值系统 |
| 17 | 粒子特效 | Presentation | Vertical Slice | Not Started | — | 打击反馈 |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | 基础框架，所有系统依赖 | 游戏状态管理, 碰撞检测, 生命值系统, 瞄准系统 |
| **Gameplay** | 核心玩法系统 | 玩家移动, 弹道系统, 敌人 AI, 关卡/楼层系统, 射击系统, Boss 战, 房间制战斗, 复活币系统, 近战攻击 |
| **Presentation** | 视觉反馈和界面 | 摄像机系统, 打击反馈, UI/HUD, 粒子特效 |

---

## Priority Tiers

| Tier | Definition | Systems | Timeline |
|------|------------|---------|----------|
| **MVP** | 核心循环必需，没有这些就无法测试"好不好玩" | 15 个 | 5 天 |
| **Vertical Slice** | 一个完整区域的体验，后续迭代 | 2 个 | +3 天 |

---

## Dependency Map

### Foundation Layer (无依赖)

1. **游戏状态管理** — 全局状态流转（开始/游戏中/暂停/死亡/重开），6 个系统依赖
2. **碰撞检测** — 子弹vs敌人、敌人vs玩家、子弹vs墙壁，7 个系统依赖（最高瓶颈）

### Core Layer (仅依赖 Foundation)

3. **生命值系统** — 玩家/敌人血量、伤害计算，6 个系统依赖。depends on: 游戏状态管理, 碰撞检测
4. **瞄准系统** — 鼠标方向输入 → 射击方向。depends on: 游戏状态管理

### Feature Layer (依赖 Core)

5. **玩家移动** — WASD 8方向移动。depends on: 碰撞检测
6. **弹道系统** — 子弹对象池、弹道类型、生命周期管理。depends on: 碰撞检测
7. **敌人 AI** — 追踪/巡逻/射击行为模式。depends on: 生命值系统, 碰撞检测
8. **关卡/楼层系统** — 房间序列、楼层推进、Boss 触发。depends on: 游戏状态管理
9. **射击系统** — 发射子弹、射速、弹幕密度。depends on: 瞄准系统, 弹道系统, 碰撞检测, 生命值系统
10. **Boss 战** — Boss 行为模式、阶段转换、专属攻击。depends on: 敌人 AI, 生命值系统, 关卡/楼层系统
11. **房间制战斗** — 进房→敌人刷新→清空→奖励→开门。depends on: 关卡/楼层系统, 敌人 AI, 游戏状态管理
12. **复活币系统** — 死亡→去色→10秒倒计时→复活/退出。depends on: 生命值系统, 游戏状态管理

### Presentation Layer (依赖 Feature)

13. **摄像机系统** — 跟随玩家、屏幕震动、Boss 入场拉远。depends on: 玩家移动
14. **打击反馈** — 命中震动、hit stop、飘字伤害、粒子。depends on: 射击系统, 生命值系统, 摄像机系统
15. **UI/HUD** — 血条、伤害飘字、Boss 血条、倒计时、菜单。depends on: 生命值系统, Boss 战, 复活币系统, 游戏状态管理

### Vertical Slice (后续迭代)

16. **近战攻击** — 近距离攻击、挥砍动画。depends on: 玩家移动, 碰撞检测, 生命值系统
17. **粒子特效** — 粒子系统、特效语言、性能预算。depends on: 打击反馈

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | 游戏状态管理 | MVP | Foundation | S |
| 2 | 碰撞检测 | MVP | Foundation | S |
| 3 | 生命值系统 | MVP | Core | S |
| 4 | 瞄准系统 | MVP | Core | S |
| 5 | 玩家移动 | MVP | Feature | S |
| 6 | 弹道系统 | MVP | Feature | M |
| 7 | 敌人 AI | MVP | Feature | M |
| 8 | 关卡/楼层系统 | MVP | Feature | S |
| 9 | 射击系统 | MVP | Feature | M |
| 10 | Boss 战 | MVP | Feature | M |
| 11 | 房间制战斗 | MVP | Feature | M |
| 12 | 复活币系统 | MVP | Feature | S |
| 13 | 摄像机系统 | MVP | Presentation | S |
| 14 | 打击反馈 | MVP | Presentation | M |
| 15 | UI/HUD | MVP | Presentation | M |
| 16 | 近战攻击 | VS | Feature | S |
| 17 | 粒子特效 | VS | Presentation | M |

Effort: S = 1 session, M = 2-3 sessions

---

## Circular Dependencies

- None found — dependency graph is a DAG (directed acyclic graph)

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 碰撞检测 | Technical | 7 个系统依赖，Web 端弹幕碰撞性能是关键 | 尽早原型，测试同屏子弹上限 |
| 弹道系统 | Technical | 对象池管理大量子弹，Web 性能受限 | 原型测试对象池方案 |
| 打击反馈 | Design | 打击感需要反复调试参数，新手开发者经验不足 | 参考 Hades/元气骑士的参数，迭代调试 |
| Boss 战 | Design | Boss 行为模式设计复杂度超出预期 | 先做简单模式，后续迭代 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 17 |
| Design docs started | 15 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 15/15 |
| Vertical Slice systems designed | 0/2 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Prototype the highest-risk system early (`/prototype 碰撞检测`)
