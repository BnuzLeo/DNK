# Game Concept: 弹幕骑士 (Bullet Knight)

*Created: 2026-05-07*
*Status: Draft*

---

## Elevator Pitch

> 这是一款俯视角 Roguelike 弹幕射击游戏，你扮演一名骑士在科技废墟中倾泻弹幕、碾压敌人、收集强化，用操作爽感征服每一个房间。像《元气骑士》一样上手简单，但弹幕密度和打击反馈拉满 — 射击本身就是目的。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 俯视角 Roguelike 弹幕射击 |
| **Platform** | Web (浏览器) |
| **Target Audience** | 想要操作爽感但没时间玩复杂游戏的玩家 |
| **Player Count** | 单人 |
| **Session Length** | 5-15 分钟一局 |
| **Monetization** | 暂不考虑 |
| **Estimated Scope** | 小 (5 天 MVP，新手开发者) |
| **Comparable Titles** | 元气骑士、Vampire Survivors、Hades |

---

## Core Fantasy

你是行走的武器平台。子弹像雨一样倾泻，敌人在弹幕中灰飞烟灭。每一次射击都有重量，每一次击杀都有反馈。你不需要思考战术，只需要感受操作的快感 — 移动、射击、碾压。在这个世界里，你的手指就是最强的武器。

---

## Unique Hook

> Like 元气骑士 AND ALSO 弹幕密度拉满，射击命中反馈（屏幕震动 + hit stop + 粒子爆炸）让每一发子弹都值得。

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (感官刺激) | 1 | 弹幕视觉、命中震动、粒子爆炸、音效冲击 |
| **Challenge** (挑战精通) | 2 | 操作精度、闪避时机、Boss 模式记忆 |
| **Fantasy** (角色幻想) | 3 | 强大的武器平台、碾压一切的力量感 |
| **Discovery** (发现探索) | 4 | 强化组合、武器搭配、新敌人模式 |
| **Expression** (自我表达) | N/A | — |
| **Narrative** (叙事) | N/A | — |
| **Fellowship** (社交) | N/A | — |
| **Submission** (放松) | N/A | — |

### Key Dynamics (Emergent player behaviors)
- 玩家会自然地尝试"边移动边射击"的走位模式
- 玩家会在清完一个房间后立刻冲进下一个房间（"再来一个"心理）
- 玩家会尝试不同的强化组合来找到最强搭配

### Core Mechanics (Systems we build)
1. **移动 + 鼠标瞄准 + 射击** — 核心操作，WASD 移动 + 鼠标瞄准方向 + 左键射击
2. **房间制战斗** — 进入房间 → 敌人刷新 → 清空 → 获得奖励
3. **敌人 AI** — 不同敌人有不同的移动和攻击模式
4. **Boss 战** — 每层末尾的强力敌人，有独特攻击模式
5. **打击反馈系统** — 屏幕震动、hit stop、飘字伤害、粒子特效

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (自由选择) | 选择强化搭配、选择武器、选择路线 | Supporting |
| **Competence** (能力成长) | 操作越来越熟练、清房越来越快、Boss 越来越轻松 | Core |
| **Relatedness** (社交连接) | 单人游戏，暂无 | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (成就者) — 收集强化、完成楼层、击败 Boss
- [x] **Killers/Competitors** (杀手型) — 操作碾压、弹幕压制、征服感
- [x] **Explorers** (探索者) — 发现强化组合、尝试不同武器搭配
- [ ] **Socializers** (社交型) — 单人游戏，暂无

### Flow State Design

- **Onboarding curve**: 前 10 秒 — WASD 移动 + 鼠标射击，敌人朝你走来，射击即命中。前 30 秒 — 清掉第一个房间，感受击杀反馈。前 2 分钟 — 进入第二个房间，敌人更多更强，需要移动躲避。
- **Difficulty scaling**: 每个房间敌人数量和种类递增，Boss 有独特攻击模式
- **Feedback clarity**: 击中 → 震动 + 粒子；击杀 → 飘字 + 爆炸；死亡 → 明确的失败提示
- **Recovery from failure**: 死亡后立刻重新开始，无惩罚，无等待

---

## Core Loop

### Moment-to-Moment (30 seconds)
玩家持续移动 + 倾泻子弹。WASD 控制移动方向，鼠标控制射击方向。子弹命中敌人 → 屏幕微震 + 命中粒子。敌人死亡 → 爆炸特效 + 飘字伤害。整个过程快速、连续、有节奏感。核心体验：**"我就是行走的武器平台，周围一切都在灰飞烟灭。"**

### Short-Term (5-15 minutes)
进入房间 → 敌人刷新 → 战斗 → 清空房间 → 获得强化 → 进入下一个房间。每个房间是独立的战斗单元，清房后有短暂喘息。"再来一个房间"的钩子：每次强化让你更强，下一个房间有新挑战。

### Session-Level (30-120 minutes)
开始一局 → 从第一层推进 → 击败 Boss → 进入下一层（或死亡重来）。一局大约 5-15 分钟。死亡后立刻重开，无惩罚。"再来一局"的钩子：这次我要试试不同的强化组合。

### Long-Term Progression
解锁新武器、新角色、新强化。操作越来越熟练，能推进得更远。发现新的强化组合。游戏"完成"的定义：击败所有 Boss，解锁所有内容。

### Retention Hooks
- **Curiosity**: 这次会随机到什么强化？这个组合会有多强？
- **Investment**: 已经解锁了 3 个武器，想试试剩下的
- **Mastery**: 上一局死在 Boss 手里，这次一定能过
- **Social**: （MVP 暂无）

---

## Game Pillars

### Pillar 1: 弹幕爽感 (Bullet Hell Satisfaction)
每一发子弹都要有存在感。射击不是手段，射击本身就是目的。子弹密度、命中反馈、敌人死亡特效 — 一切服务于"开枪就很爽"的感觉。

*Design test*: 如果我们在讨论"要不要减少子弹数量换取策略性"，这个支柱说：不，保持弹幕密度。

### Pillar 2: 即时反馈 (Immediate Impact)
玩家的每一个动作都要立刻得到视觉和听觉确认。射击命中 → 屏幕震动 + hit stop + 粒子爆炸。击杀 → 飘字 + 特效。没有延迟，没有模糊，一切都是"做了就有反应"。

*Design test*: 如果我们在讨论"要不要加一个需要等待的技能冷却系统"，这个支柱说：冷却可以有，但命中反馈不能有任何延迟。

### Pillar 3: 上瘾循环 (Addictive Loop)
"再来一个房间"和"再来一局"是最高优先级。每次强化都让人兴奋，每次死亡都让人想重来。节奏要快，停下来的时间越短越好。

*Design test*: 如果我们在讨论"要不要加一个复杂的剧情系统"，这个支柱说：不要，它会打断战斗节奏。

### Pillar 4: 像素酷炫 (Pixel Cool)
像素风不是限制，是风格。科技感、霓虹光、爆炸特效 — 像素也可以很酷。视觉上要让人觉得"这游戏看起来就很燃"。

*Design test*: 如果我们在讨论"要不要用写实风格"，这个支柱说：不要，像素科技风就是我们的视觉语言。

### Anti-Pillars (What This Game Is NOT)

- **NOT 策略游戏**: 不需要复杂的战术规划或回合制思考。我们追求的是直觉反应，不是深思熟虑。
- **NOT 叙事驱动**: 不需要复杂的剧情、对话树或过场动画。故事是背景，不是核心。
- **NOT 硬核 Roguelike**: 不需要 permadeath 带来的挫败感或极度随机性。死亡是重来的动力，不是惩罚。
- **NOT 写实风格**: 不需要逼真的物理、真实的弹道模拟或精细的 3D 模型。像素 + 酷炫特效就是我们的视觉语言。

---

## Visual Identity Anchor

**方向：像素科技废墟 (Pixel-Tech Ruins)**

- **视觉规则**: "一切都在发光或爆炸" — 像素基础上叠加科技感的霓虹光效和粒子特效
- **色彩哲学**: 深色背景 + 高饱和霓虹色（青色、品红、橙色）。暗色调的废墟中，子弹和特效是最亮的光源
- **形状语言**: 几何感 + 像素块。建筑是方正的，但特效是流动的、有机的
- **氛围**: 科技废墟中的枪火 — 黑暗、霓虹、爆炸、弹幕

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| 元气骑士 | 俯视角射击手感、房间制结构 | 更高的弹幕密度、更强的命中反馈 | 核心玩法验证 |
| Vampire Survivors | 弹幕爽感、上瘾循环 | 主动射击（不是自动攻击） | 弹幕密度参考 |
| Hades | 打击反馈、快速重开 | 更简单的系统、像素风格 | 打击感参考 |

**Non-game inspirations**: 霓虹灯城市夜景、科幻废墟概念图、重金属音乐的节奏感

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 15-30 |
| **Gaming experience** | 轻度到中度，玩过手游或休闲 PC 游戏 |
| **Time availability** | 碎片时间，5-15 分钟一局 |
| **Platform preference** | 浏览器 / 手机 |
| **Current games they play** | 元气骑士、Vampire Survivors、弹幕游戏 |
| **What they're looking for** | 快速的操作爽感，不需要学习复杂系统 |
| **What would turn them away** | 复杂的 UI、漫长的教程、等待时间 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 — 免费开源，2D 强项，Web 导出成熟 |
| **Key Technical Challenges** | Web 性能（弹幕 + 粒子）、Hit Stop 实现、Web 导出配置 |
| **Art Style** | 像素风 |
| **Art Pipeline Complexity** | 低 (像素素材 + 粒子特效) |
| **Audio Needs** | 中等 (射击音效、命中反馈、BGM) |
| **Networking** | 无 |
| **Content Volume** | MVP: 3 个房间 + 1 个 Boss |
| **Procedural Systems** | 房间布局可随机（MVP 可用固定布局） |

---

## Risks and Open Questions

### Design Risks
- 核心射击手感可能不够爽 — 需要反复调试震动、hit stop、粒子参数
- 弹幕密度和性能的平衡 — Web 端性能有限

### Technical Risks
- Web 导出性能瓶颈 — 大量子弹 + 粒子可能导致帧率下降
- Godot Web 导出需要 SharedArrayBuffer — 部分浏览器/服务器可能不支持

### Market Risks
- 俯视角射击游戏竞争激烈 — 需要在打击感上做出差异化
- Web 游戏用户获取比移动端难

### Scope Risks
- 5 天 MVP 对新手开发者来说非常紧张
- 打击感调试可能比预期花更多时间

### Open Questions
- Web 端能支持多少同屏子弹？需要原型测试
- Hit Stop 在 Godot 中的最佳实现方式是什么？

---

## MVP Definition

**核心假设**: 玩家觉得"射击手感爽 + 清房间有成就感"，愿意连续玩 3 个房间以上。

**MVP 必须包含**:
1. WASD 移动 + 鼠标瞄准 + 射击 — 核心操作
2. 3 个房间 + 敌人刷新 + 清房逻辑 — 核心结构
3. 屏幕震动 + 飘字伤害 — 基础打击反馈
4. 敌人 AI（追踪 + 射击）— 战斗对象
5. Boss 战（1 个 Boss）— 单局高潮
6. 死亡 → 重开 — 快速循环

**MVP 不包含**（后续迭代）:
- 强化系统
- 多种武器
- Hit stop
- 粒子特效系统
- 音效
- 多层关卡
- 角色解锁

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP 核心** | 1 个房间 + 基础敌人 | 移动 + 射击 + 碰撞 | 2 天 |
| **MVP 完整** | 3 个房间 + Boss | 屏幕震动 + 飘字 + 敌人AI | 2 天 |
| **Vertical Slice** | 5 个房间 + Boss + 强化 | Hit stop + 粒子 + 近战 | 3 天 |
| **Alpha** | 多层 + 多武器 + 强化系统 | 全功能，粗糙 | 2 周 |

---

## Next Steps

- [ ] 配置引擎 (`/setup-engine`) — 设置 Godot 4 + GDScript
- [ ] 创建美术圣经 (`/art-bible`) — 定义像素科技风视觉规范
- [ ] 拆解系统 (`/map-systems`) — 将概念分解为独立系统
- [ ] 编写系统 GDD (`/design-system`) — 为每个 MVP 系统编写详细设计
- [ ] 创建架构 (`/create-architecture`) — 生成主架构蓝图
- [ ] 原型验证 (`/prototype`) — 构建核心射击手感原型
- [ ] 测试报告 (`/playtest-report`) — 验证核心假设
- [ ] 计划冲刺 (`/sprint-plan new`) — 规划第一个冲刺
