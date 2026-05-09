# DNK 视觉素材规范 v1

本文件用于锁定《DNK / 坤坤地下城》当前版本进入贴图阶段后的统一交付标准。

目标有两个：

1. 指导素材准备，避免尺寸、命名、朝向、导出规则反复返工。
2. 约束后续接入方式。后面我在把素材接入 Godot 时，会默认严格按这份清单执行。


## 1. 锁定的技术基线

- 游戏运行分辨率：`960x640`
- 当前摄像机和 UI 坐标体系：按 `960x640` 固定画布设计
- 游戏视角：`2D 顶视 / 近顶视`，不使用强正面透视
- 当前世界单位：`1 个 Godot world unit ~= 1 屏幕像素`
- 当前视觉占位多数是代码绘制；贴图接入后，优先保持现有碰撞和判定不变，只替换可视层
- 当前项目建议锁定风格：`非像素风 2D 栅格贴图`，清晰轮廓、明暗简洁、可读性优先

重要约束：

- 旋转类战斗单位的基础朝向统一为：`朝右`
  - 包括：玩家、普通敌人、Boss、子弹、飞镖、喷射器锥形贴图
  - 原因：现有逻辑大量基于 `Vector2.RIGHT` 和角度旋转，朝右是最低成本接入标准
- 动画序列必须使用固定画布，不允许逐帧裁切尺寸漂移
- 角色和道具的透明边缘不能有黑边、脏边、预乘 Alpha 残留


## 2. 交付格式与文件规则

### 2.1 文件格式

- 源文件：`PSD`、`Aseprite` 或等价分层源文件
- 接入文件：`PNG 32-bit RGBA`
- 色彩空间：`sRGB`
- 分辨率标记：DPI 不重要，像素尺寸才重要

### 2.2 交付层级

每个素材建议同时提供两份：

1. `source` 源文件
2. `export` 接入 PNG

默认标准：

- 源文件按接入尺寸的 `2x` 制作
- 最终接入 PNG 为 `1x`
- 引擎内通常按 `1.0` 显示；如果后续我采用统一高精缩放方案，会在接入时明确说明

### 2.3 命名规则

统一格式：

`{category}_{subject}_{variant}_{state}_{size|strip}.png`

示例：

- `char_player_body_idle_strip4.png`
- `enemy_chaser_move_strip6.png`
- `weapon_shotgun_icon_64.png`
- `ui_panel_dark_9slice_64.png`
- `env_portal_lobby_strip8.png`

补充规则：

- 全部小写
- 单词之间使用下划线
- 不要在文件名中写中文、空格、版本后缀
- 动画序列统一用整张横向条带，后缀写 `strip{帧数}`


## 3. Godot 接入约束

后续接入默认遵循：

- 角色/道具：`Sprite2D` 或 `AnimatedSprite2D`
- UI 面板：`NinePatchRect`、`TextureRect`、`StyleBoxTexture`
- 透明贴图压缩：`Lossless`
- `Mipmaps = Off`
- `Repeat = Off`
- 仅无缝地面/墙面纹理允许 `Repeat = Enabled`
- 非像素风默认 `Filter = Linear`

接入时不立即改动的内容：

- 碰撞体大小
- 子弹命中半径
- 房间、门洞、走廊尺寸
- 背包槽位和 UI 布局尺寸


## 4. 统一尺寸标准

这部分是后续所有素材准备的硬标准。

### 4.1 世界对象尺寸定义方式

每个世界素材都看三个尺寸：

1. `源画布`：美术制作尺寸
2. `接入 PNG`：实际导入 Godot 的单帧尺寸
3. `游戏显示尺寸`：屏幕上最终目标占地

如果没有特殊说明，角色和道具一律以透明留白方式放在固定画布内，不要刚好顶边。

### 4.2 UI 对象尺寸定义方式

UI 直接按当前布局尺寸准备，不做模糊缩放设计。

- 面板、按钮、槽位、卡片：按实际 UI 尺寸出图
- 能做 9-slice 的，优先做 9-slice，不做整张死尺寸大图


## 5. 素材清单

下面按 `M1 必做` 和 `M2 增强` 两档整理。

- `M1`：首批就该准备，我接入时会优先使用
- `M2`：第二轮增强项，当前可以继续先用代码绘制


## 5.1 角色与敌人

### M1 必做

| ID | 用途 | 源画布 | 接入 PNG | 游戏显示 | Pivot | 朝向 | 动画要求 |
|---|---|---:|---:|---:|---|---|---|
| `char_player_body` | 玩家主体 | `128x128` | `64x64/帧` | `32x32` | 中心 | 朝右 | `idle 4` / `move 8` / `dash 4` / `hit 2` / `dead 6` |
| `enemy_chaser_body` | 追击怪 | `128x128` | `64x64/帧` | `30~32x32` | 中心 | 朝右 | `idle 4` / `move 6` / `hit 2` / `dead 4` |
| `enemy_shooter_body` | 射手怪 | `128x128` | `64x64/帧` | `32x32` | 中心 | 朝右 | `idle 4` / `move 6` / `tell 4` / `dead 4` |
| `enemy_tank_body` | 坦克怪 | `128x128` | `64x64/帧` | `36x36` | 中心 | 朝右 | `idle 4` / `move 6` / `hit 2` / `dead 4` |
| `enemy_swarm_body` | 小型群怪 | `96x96` | `48x48/帧` | `24x24` | 中心 | 朝右 | `idle 4` / `move 6` / `dead 4` |
| `boss_main_body` | Boss 主体 | `256x256` | `128x128/帧` | `64x64` | 中心 | 朝右 | `idle 6` / `tell 4` / `dash 6` / `dead 8` |
| `npc_broker_body` | 经纪人 NPC | `256x256` | `128x128/帧` | 高 `80` 左右 | 底部中心 | 固定朝下/朝玩家 | `idle 4`，至少可先交 `idle 1` |
| `npc_smith_body` | 铁匠 NPC | `256x256` | `128x128/帧` | 高 `80` 左右 | 底部中心 | 固定朝下/朝玩家 | `idle 4`，至少可先交 `idle 1` |

说明：

- 玩家当前碰撞半径是 `8`，所以角色视觉可以略大于碰撞，不要把头身做得过宽。
- 普通敌人当前碰撞半径基本也是 `8`，Tank 允许视觉略大，但不要把碰撞外观做成严重误导。
- Boss 当前碰撞半径是 `24`，显示做 `64x64` 合适。

### M2 增强

| ID | 用途 | 源画布 | 接入 PNG | 游戏显示 | 备注 |
|---|---|---:|---:|---:|---|
| `char_player_shadow` | 玩家地面阴影 | `128x64` | `64x32` | `24x12` | 独立透明阴影，不烘焙进主体 |
| `enemy_common_shadow` | 小怪阴影 | `128x64` | `64x32` | `20x10` | 可共用 |
| `boss_shadow` | Boss 阴影 | `256x128` | `128x64` | `48x24` | 可共用单帧 |


## 5.2 武器与战斗效果

### M1 必做

#### 武器 UI 图标

| ID | 用途 | 源画布 | 接入 PNG | UI 显示 | Pivot | 朝向 |
|---|---|---:|---:|---:|---|---|
| `weapon_pistol_icon` | 小手枪图标 | `128x128` | `64x64` | `48x48` | 中心 | 朝右 |
| `weapon_shotgun_icon` | 散弹枪图标 | `128x128` | `64x64` | `48x48` | 中心 | 朝右 |
| `weapon_gatling_icon` | 加特林图标 | `128x128` | `64x64` | `48x48` | 中心 | 朝右 |
| `weapon_freeze_icon` | 冰冻喷射器图标 | `128x128` | `64x64` | `48x48` | 中心 | 朝右 |
| `weapon_dart_icon` | 飞镖图标 | `128x128` | `64x64` | `48x48` | 中心 | 朝右 |

#### 投射物

| ID | 用途 | 源画布 | 接入 PNG | 游戏显示 | Pivot | 朝向 |
|---|---|---:|---:|---:|---|---|
| `proj_bullet_player` | 玩家普通子弹 | `32x32` | `16x16` | `12x12` | 中心 | 朝右 |
| `proj_bullet_enemy` | 敌方子弹 | `32x32` | `16x16` | `12x12` | 中心 | 朝右 |
| `proj_dart` | 飞镖本体 | `64x64` | `32x32` | `16x12` | 中心 | 朝右 |
| `fx_freeze_cone` | 喷射器锥形贴图 | `512x256` | `256x128` | 长 `100~120` | 左边中点 | 朝右 |

说明：

- 子弹不建议做太复杂，优先保证高速移动下的辨识度。
- 喷射器贴图必须是左边发射、向右展开，方便后续按角度旋转。

### M2 增强

| ID | 用途 | 源画布 | 接入 PNG | 游戏显示 | 动画要求 |
|---|---|---:|---:|---:|---|
| `fx_muzzle_small` | 手枪/加特林枪口火焰 | `128x128` | `64x64/帧` | `20x20` | `strip4` |
| `fx_muzzle_shotgun` | 散弹枪枪口火焰 | `128x128` | `64x64/帧` | `28x28` | `strip4` |
| `fx_hit_spark` | 命中火花 | `128x128` | `64x64/帧` | `20x20` | `strip5` |
| `fx_dash_trail` | 玩家闪避拖尾 | `256x128` | `128x64/帧` | 动态拉伸 | `strip4` |
| `fx_boss_dash_trail` | Boss 冲刺拖尾 | `256x128` | `128x64/帧` | 动态拉伸 | `strip4` |
| `fx_explosion_ring` | 爆炸圈 | `256x256` | `128x128/帧` | 半径 `100` | `strip8` |
| `fx_spawn_warning` | 出怪预警圈 | `128x128` | `64x64/帧` | `28x28` | `strip6` |


## 5.3 地图、环境与道具

### M1 必做

#### 无缝纹理

| ID | 用途 | 源画布 | 接入 PNG | 贴图方式 | 备注 |
|---|---|---:|---:|---|---|
| `tile_dungeon_floor` | 地牢普通房间地板 | `512x512` | `256x256` | Repeat | 必须四边无缝 |
| `tile_dungeon_wall` | 地牢墙体表面 | `512x512` | `256x256` | Repeat | 可做亮暗变化 |
| `tile_dungeon_corridor` | 走廊地面 | `512x512` | `256x256` | Repeat | 可复用 floor，但建议独立一张 |
| `tile_start_floor` | 起始房地面 | `512x512` | `256x256` | Repeat | 比普通地牢更安全、更亮 |
| `tile_boss_floor` | Boss 房地面 | `512x512` | `256x256` | Repeat | 明确区分普通房 |
| `tile_lobby_floor` | 基地地面 | `512x512` | `256x256` | Repeat | 需要更干净、更有人味 |
| `tile_lobby_wall` | 基地墙体 | `512x512` | `256x256` | Repeat | 可与地面分层 |

#### 门、传送门、宝箱、障碍

| ID | 用途 | 源画布 | 接入 PNG | 游戏显示 | Pivot | 动画要求 |
|---|---|---:|---:|---:|---|---|
| `env_door_locked_h` | 横向锁门 | `192x48` | `96x24` | `80x12` | 中心 | 单帧 |
| `env_door_locked_v` | 纵向锁门 | `48x192` | `24x96` | `12x80` | 中心 | 单帧 |
| `env_portal_lobby` | 基地传送门 | `256x256` | `128x128/帧` | `50x50` | 中心 | `strip8` |
| `env_portal_dungeon` | Boss 房返程传送门 | `256x256` | `128x128/帧` | `60x60` | 中心 | `strip8` |
| `prop_chest_normal` | 普通宝箱 | `128x128` | `64x64/帧` | `32x32` | 底部中心 | `closed 1 / open 1 / open_strip6` |
| `prop_chest_weapon` | 武器三选一宝箱 | `128x128` | `64x64/帧` | `32x32` | 底部中心 | 与普通宝箱同规格，可换色 |
| `prop_crate_wood` | 木箱障碍 | `128x128` | `64x64` | `32x32` | 底部中心 | 单帧，允许做破损版增强 |

说明：

- 房间门当前逻辑尺寸固定：横门以 `80x12` 为基准，竖门以 `12x80` 为基准。
- 门贴图允许比判定稍厚，但有效视觉中心必须对齐门洞中心。

### M2 增强

| ID | 用途 | 源画布 | 接入 PNG | 游戏显示 | 备注 |
|---|---|---:|---:|---:|---|
| `prop_crate_wood_broken` | 木箱破碎态 | `128x128` | `64x64/帧` | `32x32` | `strip4` |
| `trap_spike` | 地刺陷阱 | `128x128` | `64x64/帧` | `32x32` | 当前未在主流程生成，但规格先锁 |
| `hazard_patch_lava` | 危险地面贴图 | `256x256` | `128x128` | `50x36 ~ 64x48` | 当前未接入，后面可做平铺或 decal |
| `hazard_patch_poison` | 毒池变体 | `256x256` | `128x128` | `50x36 ~ 64x48` | 可选 |


## 5.4 UI 与菜单

### 5.4.1 通用 UI Kit

优先做可复用而不是每个面板单独出死图。

| ID | 用途 | 源画布 | 接入 PNG | 目标尺寸 | 备注 |
|---|---|---:|---:|---:|---|
| `ui_panel_dark_9slice` | 深色主面板 | `128x128` | `64x64` | 可拉伸 | 四角建议 `8~12 px` |
| `ui_panel_blue_9slice` | 蓝色系统面板 | `128x128` | `64x64` | 可拉伸 | 用于商店/地图等 |
| `ui_panel_green_9slice` | 绿色装备面板 | `128x128` | `64x64` | 可拉伸 | 用于背包/装备 |
| `ui_panel_gold_9slice` | 金色强化面板 | `128x128` | `64x64` | 可拉伸 | 用于标题/稀有面板 |
| `ui_btn_primary_9slice` | 主按钮 | `128x64` | `64x32` | 可拉伸 | 常规确认按钮 |
| `ui_btn_secondary_9slice` | 次按钮 | `128x64` | `64x32` | 可拉伸 | 取消/返回 |
| `ui_btn_danger_9slice` | 危险按钮 | `128x64` | `64x32` | 可拉伸 | 重置/放弃 |
| `ui_keycap_square` | 按键图标底板 | `72x72` | `36x36` | `36x36` | 用于 J/Q/K |

### 5.4.2 HUD 与战斗 UI

| ID | 用途 | 源画布 | 接入 PNG | UI 显示 | 备注 |
|---|---|---:|---:|---:|---|
| `ui_hp_frame` | HP 外框 | `204x28` | `102x14` | `102x14` | 也可做 9-slice |
| `ui_hp_fill` | HP 填充 | `200x24` | `100x12` | 宽度动态 | 左对齐缩放 |
| `ui_mana_frame` | MP 外框 | `204x20` | `102x10` | `102x10` | 也可做 9-slice |
| `ui_mana_fill` | MP 填充 | `200x16` | `100x8` | 宽度动态 | 左对齐缩放 |
| `ui_boss_hp_frame` | Boss 血条框 | `1000x32` | `500x16` | `500x16` | 可做 9-slice |
| `ui_boss_hp_fill` | Boss 血条填充 | `996x28` | `498x14` | 宽度动态 | 左对齐缩放 |
| `ui_buff_chip` | Buff 条底板 | `144x40` | `72x20` | `72x20` | 4 类 Buff 共用底板 |
| `ui_buff_icon_mana_regen` | Buff 图标：回蓝 | `48x48` | `24x24` | `16~20` | 透明背景 |
| `ui_buff_icon_speed` | Buff 图标：移速 | `48x48` | `24x24` | `16~20` | 透明背景 |
| `ui_buff_icon_revive` | Buff 图标：复活 | `48x48` | `24x24` | `16~20` | 透明背景 |
| `ui_buff_icon_bullet` | Buff 图标：弹道 | `48x48` | `24x24` | `16~20` | 透明背景 |
| `ui_action_attack` | 攻击图标 | `72x72` | `36x36` | `36x36` | 对应 J |
| `ui_action_switch` | 切枪图标 | `72x72` | `36x36` | `36x36` | 对应 Q |
| `ui_action_dash` | 闪避图标 | `72x72` | `36x36` | `36x36` | 对应 K |

### 5.4.3 装备/商店/地图选择

| ID | 用途 | 源画布 | 接入 PNG | UI 显示 | 备注 |
|---|---|---:|---:|---:|---|
| `ui_slot_weapon_bg` | 装备槽底板 | `240x160` | `120x80` | `120x80` | 装备槽、背包槽共用 |
| `ui_slot_weapon_locked` | 锁定装备槽底板 | `240x160` | `120x80` | `120x80` | 与普通槽区分明显 |
| `ui_slot_highlight` | 槽位高亮边框 | `240x160` | `120x80` | `120x80` | 透明中心 |
| `ui_card_map_bg` | 地图选择卡底 | `360x480` | `180x240` | `180x240` | 选中/未选中可分两态 |
| `ui_thumb_mine_ruins` | 废弃矿洞缩略图 | `328x320` | `164x160` | `164x160` | 对应当前卡片 thumb 区域 |
| `ui_thumb_locked` | 未开放地图缩略图 | `328x320` | `164x160` | `164x160` | 可复用 |
| `ui_card_weapon_bg` | 武器三选一卡片底 | `480x560` | `240x280` | `240x280` | 宝箱三选一使用 |
| `ui_shop_row_bg` | 商店行底板 | `1280x152` | `640x76` | `640x76` | 单行武器商品 |

### 5.4.4 标题与通用覆盖层

| ID | 用途 | 源画布 | 接入 PNG | UI 显示 | 备注 |
|---|---|---:|---:|---:|---|
| `bg_title_main` | 标题页背景 | `1920x1280` | `960x640` | `960x640` | 不做分屏，完整首屏图 |
| `ui_overlay_pause` | 暂停背景叠层 | `1920x1280` | `960x640` | `960x640` | 可只提供噪点/暗纹，不一定纯色 |
| `ui_overlay_gameover` | Game Over 覆盖层 | `1920x1280` | `960x640` | `960x640` | 可复用 pause 基底 |
| `ui_overlay_revive` | 复活界面覆盖层 | `1920x1280` | `960x640` | `960x640` | 可复用 pause 基底 |


## 5.5 字体与非贴图资源

虽然当前阶段主要是贴图，但下面两类也建议同步锁定，否则 UI 成品感会卡住。

### M1 必做

| ID | 类型 | 要求 |
|---|---|---|
| `font_ui_main` | TTF / OTF | 必须覆盖简体中文、数字、英文、常用符号 |
| `font_display_title` | TTF / OTF | 用于标题、Boss、重要弹窗，风格可更强，但也要支持中文 |

### M2 增强

| ID | 类型 | 要求 |
|---|---|---|
| `font_damage_numbers` | TTF / OTF | 用于飘字，可与标题字体共用 |


## 6. 目录建议

建议按下面结构准备，后面我接入时也会按这个结构落地：

```text
DNK/
  assets/
    source/
      characters/
      enemies/
      bosses/
      weapons/
      environment/
      ui/
      fonts/
    export/
      characters/
      enemies/
      bosses/
      weapons/
      environment/
      ui/
      fonts/
```

更细一级建议：

```text
assets/export/characters/player/
assets/export/enemies/chaser/
assets/export/enemies/shooter/
assets/export/enemies/tank/
assets/export/enemies/swarm/
assets/export/bosses/main/
assets/export/weapons/icons/
assets/export/environment/tiles/
assets/export/environment/props/
assets/export/environment/portal/
assets/export/ui/panels/
assets/export/ui/icons/
assets/export/ui/cards/
assets/export/ui/slots/
assets/export/fonts/
```


## 7. 具体接入策略说明

后面实际接入时，默认这么处理：

### 7.1 玩家/敌人/Boss

- 先替换现有 `_draw()` 占位图
- 优先不改碰撞和伤害数值
- 玩家和战斗单位如果做了多帧，我会优先接 `AnimatedSprite2D`
- 如果首批只交单帧，也可以先接 `Sprite2D`，不阻塞贴图阶段

### 7.2 房间与地面

- 当前房间是程序生成，不适合先做大整张房间背景
- 第一轮优先接：`无缝地板纹理` + `墙面纹理` + `门` + `传送门`
- 不建议在这一版直接准备整张固定房间底图，因为房间和走廊是动态拼出来的

### 7.3 UI

- 第一轮优先把 `UI Kit` 做出来，能覆盖商店、背包、地图选择、暂停、复活、Boss 血条
- 装备槽和商店武器卡不要把文字烘焙进贴图
- 图标与底板分离，方便后续状态切换、价格、锁定、选中高亮


## 8. 当前代码尺寸映射依据

下面这些是本规范锁定尺寸的直接来源，后续不要随意改，除非同时改代码布局：

- 视口：`960x640`
- 地牢房间：`700x400`
- 地牢单元格：`960x640`
- 走廊宽：`80`
- 墙厚：`12`
- 玩家碰撞半径：`8`
- 普通敌人碰撞半径：`8`
- Boss 碰撞半径：`24`
- 宝箱碰撞半径：`16`
- 装备槽：`120x80`
- 地图选择卡：`180x240`
- 地图缩略图区域：`164x160`
- 武器三选一卡：`240x280`
- 技能按键图标：`36x36`
- Buff 条：`72x20`
- HP 条：`102x14`
- MP 条：`102x10`
- Boss 血条：`500x16`


## 9. 首批交付建议顺序

如果你要按最小返工路线准备，建议按这个顺序出图：

1. `font_ui_main`、`font_display_title`
2. `ui_panel_*`、`ui_btn_*`、`ui_keycap_square`
3. `weapon_*_icon`
4. `char_player_body`
5. `enemy_*_body`
6. `boss_main_body`
7. `npc_broker_body`、`npc_smith_body`
8. `tile_dungeon_floor`、`tile_dungeon_wall`、`tile_lobby_floor`、`tile_lobby_wall`
9. `env_portal_*`
10. `prop_chest_*`、`prop_crate_wood`
11. `ui_thumb_mine_ruins`、`bg_title_main`
12. 再做所有 `M2` 增强项


## 10. 验收清单

每个素材交付前，按下面标准自检：

- 透明背景正确，没有底色残留
- 基础朝向正确，旋转类一律朝右
- 每个动作所有帧画布完全一致
- 角色主体不要贴边，留足 5%~10% 安全边距
- 无缝纹理四边拼接无明显断层
- UI 贴图不要烘焙动态文字
- 中文字体能覆盖界面所有现有文案
- 文件命名符合本规范
- 同一对象的 source 和 export 一一对应


## 11. 执行口径

从现在开始，这份文档就是视觉素材接入的标准口径。

后面如果你把素材按这份规范准备给我，我会默认：

- 不再重新询问尺寸
- 不再重新定义 Pivot
- 不再重新定义朝向
- 不再重新设计 UI 贴图规格

只有在以下情况我才会建议你返工规格：

- 你临时改成像素风
- 你想把角色系统升级成 8 向独立朝向动画
- 你要把程序绘制房间彻底改成 TileMap 驱动
- 你要把 UI 从固定 `960x640` 改成响应式多分辨率

