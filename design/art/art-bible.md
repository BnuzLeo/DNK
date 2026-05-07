# Art Bible: 弹幕骑士 (Bullet Knight)

*Created: 2026-05-07*
*Status: Draft — Sections 1-4 (Visual Identity Core)*
*Scope: 5 天 MVP — 聚焦可执行的视觉规范*

---

## 1. Visual Identity Statement

### Primary Visual Rule

> **"Dark stage, bright actors."** Backgrounds are always darker than gameplay elements; nothing in the environment competes with bullets, effects, or the player for visual attention.

This single rule resolves most ambiguity because it answers the core question every asset poses: "Should this be brighter or darker?" It directly serves **Pillar 1 (弹幕爽感)** by ensuring dense bullet patterns are always readable against their backdrop. When in doubt, darken the background or brighten the foreground — never the reverse.

### Supporting Principles

**Principle 1: "Every bullet is a light source."**

*Anchored to: Pillar 2 — Immediate Impact (即时反馈)*

Every projectile, hit effect, and explosion emits a small glow halo. This turns each bullet into both a threat and a visual reward — the player sees their firepower literally illuminate the room. The glow reinforces that the shot connected, the explosion landed, the combo is building.

*Design test: When two effects overlap and it is unclear which belongs to which, ask: "Does each one glow independently?" If yes, they are distinct. If they blend into a single glow, add color contrast or size difference to separate them.*

**Principle 2: "Neon on concrete."**

*Anchored to: Pillar 4 — Pixel Cool (像素酷炫)*

Every scene uses exactly two material languages: muted, desaturated grays and browns for structural elements (walls, floors, debris), and high-saturation neon (cyan, magenta, orange) for all interactive or hostile elements. There is never a third material language. This constraint keeps the pixel art simple to produce, keeps visual hierarchy automatic (you always know what to look at), and creates the "科技废墟" aesthetic without requiring complex rendering.

*Design test: When a new asset is being created, ask: "Is this structural or interactive?" Structural = desaturated pixel fill, no glow. Interactive = neon-saturated fill + optional glow. If the answer is ambiguous, it is structural — only things that damage the player or that the player shoots should glow.*

**Principle 3: "Less than four."**

*Anchored to: Pillar 3 — Addictive Loop (上瘾循环) + Pillar 1 — Bullet Hell Satisfaction (弹幕爽感)*

Every screen (room, HUD, menu) uses a maximum of three dominant neon colors plus black/gray. This keeps visual density manageable even when bullet counts are high, and it allows the player's brain to build fast pattern recognition — cyan enemies, magenta hazards, orange pickups become instinct rather than conscious reading. Faster pattern recognition means faster room clears, which feeds the "one more room" rhythm.

*Design test: When a room or screen feels "busy," count the distinct neon hues. If there are more than three, merge the least important color into an existing one. Color is the cheapest tool for reducing cognitive load in a bullet hell.*

### Summary

| Principle | Pillar Served | One-Line Rule |
|---|---|---|
| **Dark stage, bright actors** (primary) | 弹幕爽感 | Backgrounds are always darker than gameplay elements |
| **Every bullet is a light source** | 即时反馈 | Each projectile and effect emits its own glow |
| **Neon on concrete** | 像素酷炫 | Two material languages only: muted structure, neon interactive |
| **Less than four** | 上瘾循环 + 弹幕爽感 | Max 3 neon hues per screen for fast pattern recognition |

## 2. Mood & Atmosphere

### 2.1 Core Emotional Arc

The game oscillates between two states: **cool control** (exploring, clearing rooms) and **hot intensity** (boss fights, near-death, high combo counts). The visual language must flip between these states instantly — the player should feel the temperature change before they consciously register what changed.

| State | Visual Signature | Trigger |
|---|---|---|
| **Cool** | Desaturated backgrounds, muted ambient lighting, slow particle drift | Room exploration, low combo, menu screens |
| **Hot** | Saturated neon pulses, screen shake, glow intensification, fast particles | Boss encounter, high combo (15+), countdown timer, death |

This duality is the heartbeat of the game's atmosphere. Every room transitions between these states as the player enters combat and exits it, reinforcing the rhythm of tension and release.

### 2.2 Lighting Direction

**Ambient baseline:** Rooms are lit with a single, low-intensity directional light from above-left, casting long soft shadows. This is the "cool" state baseline. No room is ever fully dark — the player must always see the floor grid and walls clearly.

**Combat lighting:** When enemies spawn, a subtle warm tint (2-5% shift toward orange) washes over the ambient. This is barely perceptible consciously but registers as increased urgency. Boss arenas push this further — the ambient shifts toward magenta (2-3% shift), pre-associating the room with the boss palette.

**Effect lighting:** Every projectile, hit, and explosion contributes its own point light (small radius, high intensity). In a room with 50+ active bullets, this creates a dynamic, self-illuminating environment where the player's screen is literally brighter during intense combat — reinforcing the "hot" state.

**No baked lightmaps.** All lighting is runtime or pre-baked to a single flat ambient per room. Complex GI is out of scope for MVP. Use colored ambient light + point lights from effects only.

### 2.3 Particle Language

Particles are the primary tool for atmosphere. Every room has at minimum three particle layers:

| Layer | Purpose | Density | Behavior |
|---|---|---|---|
| **Ambient dust** | Establishes "abandoned facility" mood | Sparse (3-8 active) | Slow vertical drift, low opacity, desaturated gray |
| **Combat sparks** | Rewards hits, builds intensity | Moderate (10-20 active) | Fast outward burst from impact point, bright neon color matching the source (cyan bullet = cyan spark) |
| **Screen-edge vignette** | Communicates danger state | 0 or 1 | Pulsing dark overlay at screen edges when HP is low or countdown is active |

**Constraint:** Total particle count across all layers must stay under 30 active at any time. This is a hard performance budget for mobile compatibility. If the count exceeds 30, reduce ambient dust first (it contributes least to gameplay feedback).

### 2.4 Screen Shake & Camera Behavior

**Baseline:** Camera is locked to the player with zero shake. The view is stable and predictable — essential for reading bullet patterns.

**Hit feedback:** Enemy death triggers a 0.1s horizontal shake (2px amplitude, quick decay). Player hit triggers a 0.15s radial shake (4px amplitude, quick decay). These are the only two shake triggers in normal gameplay.

**Boss entrance:** When a boss spawns, the camera pulls back 5% over 0.5s, then locks. This creates a subtle "oh no" moment — the space suddenly feels larger and the player feels smaller.

**No shake on player shot.** The player fires hundreds of times per minute; shake on every shot would be visual noise. Shake is reserved for impacts, not actions.

### 2.5 Death Sequence

When the player dies, the visual treatment is immediate and total:

**Frame 1:** Instant cut to full desaturation. The entire screen loses all color in a single frame — no transition, no drain, no fade. The background goes grayscale, all neon elements lose saturation, the screen darkens 20%.

**Frame 2 onward:** A Hot Pink (RGB: 255, 105, 180) countdown numeral appears centered on screen: 3, 2, 1, then respawn. The numeral is rendered in the game's pixel font at 3x scale with a subtle glow. Hot Pink was chosen because it ties directly to the boss palette — it is the color of threat and danger in this game's visual language, so the countdown carries the emotional weight of "you are still in danger" rather than "rest and recover."

**Frame 1 of respawn:** Full color returns instantly. The contrast between grayscale death and full-color respawn is itself a reward — the world coming back to life feels good.

**Why instant, not gradual:** A gradual desaturation drain (0.5-1 second) looks better in isolation but costs animation frames and polish time. For a 5-day MVP, instant is cheaper, punchier, and more readable at high speed. The player dies, the world goes gray, the countdown starts — no ambiguity, no waiting.

### 2.6 Main Menu

The title screen is not a static image or a slow atmospheric pan. It is a **short, looping combat vignette** — 5-8 seconds of hand-animated gameplay showing the Knight fighting through a room, ending on a boss spawn. The loop cuts hard back to the start, creating a seamless "this is what you do" introduction.

**Visual treatment:** The vignette uses the same art style as in-game but with slightly tighter framing (zoomed in 10%) to emphasize action. The background is darker than standard gameplay — the Knight and bullets are the only bright elements. The game logo sits in the upper third with a subtle neon glow that pulses in time with the combat below.

**Why 5-8 seconds:** Long enough to show a full combat rhythm (approach, clear, boss cue), short enough that it never feels like a demo the player is forced to watch. It loops seamlessly so it can play indefinitely without becoming stale.

**Audio pairing:** No music on the title screen — just the raw sound effects of combat (gunfire, impacts, the boss spawn sting). This lets the visual action speak for itself and creates an inviting contrast with the music that starts when the player presses start.

## 3. Shape Language

### 3.1 Design Philosophy: Readability Through Contrast

Shape language in Bullet Knight follows the same governing rule as every other visual layer: **the player must know what matters in under 100 milliseconds.** At 16x16 to 32x32 sprite sizes on a web browser, there is no room for subtlety of form. Shapes must be extreme — aggressively readable silhouettes that communicate threat, safety, or opportunity at a glance.

The shape vocabulary splits the entire game into two categories, mirroring the "neon on concrete" material principle:

| Category | Shape Language | Emotional Read |
|---|---|---|
| **Structural** (walls, floors, debris) | Rectangular, grid-aligned, broken fragments | "This is the world. It does not move. It does not care." |
| **Interactive** (player, enemies, bullets, pickups) | Rounded or angular with clear directional bias | "This does something. Watch it." |

This split is not merely aesthetic — it directly serves **Pillar 1 (弹幕爽感)** by ensuring the player's eye never lingers on non-essential geometry. Structural shapes are boring on purpose. Interactive shapes are distinctive on purpose.

### 3.2 Character Silhouette Philosophy

**The 3-pixel rule:** A character silhouette must be recognizable at 3 pixels of difference. If you shrink any character to a 6x6 blob and remove all color, you should still tell the player from an enemy. This is the hard constraint for 16x16 pixel art at browser viewport distances.

**Silhouette hierarchy by archetype:**

| Archetype | Dominant Shape | Silhouette Signature | Why It Works |
|---|---|---|---|
| **Player (Knight)** | Rectangle + triangle | Broad shoulders tapering to a narrow base; helmet horn pointing up-right | The only upward-pointing triangle in the game. Player instinctively associates "upward = me." The broad top also makes the Knight feel grounded and sturdy — a survivor, not a speedster. |
| **Regular enemies** | Circle + stub | Rounded body with short, stubby limbs; no vertical protrusions | Deliberately non-threatening individually. The roundness says "not sharp, not dangerous" — until 20 of them fill the screen. Mass, not individual threat. |
| **Bosses** | Irregular / asymmetric | Large dominant mass with one extreme protrusion (spike, claw, horn) | Asymmetry signals "wrong" and "unnatural." The player reads a boss as a disruption of the room's geometry before they register its attacks. The single protrusion is the attack tell — where it points is where the danger comes from. |
| **Projectiles** | Dot or bar | Perfect circle (enemy) or short bar (player) | Minimal shapes that scale cleanly. Circles read as "hazard incoming" across any size. Bars read as "ammunition" — familiar from decades of shoot-em-up convention. |
| **Pickups / items** | Star or diamond | Rotated square or 4-point star | The only shapes in the game that use diagonal lines. Diagonal = opportunity, because nothing else in the environment rotates off-grid. The player's eye snaps to diagonals. |

**Emotional subtext:** The Knight is angular and grounded (strength, determination). Enemies are round and numerous (swarm, overwhelming). Bosses are jagged and singular (wrongness, dread). Pickups are bright and diagonal (relief, reward). Every shape tells the player how to feel about what they see before they read a single pixel of color.

### 3.3 Environment Geometry

**Dominant language: Orthogonal with controlled decay.**

The world is built on a strict grid — walls are rectangles, floors are tiled squares, pillars are squared columns. This is the "concrete" in "neon on concrete." The grid says: *this was built, this was orderly, this was once a functioning place.*

**Decay introduces the personality:**

- Walls have broken edges — not smooth curves, but jagged rectangular fragments, as if chunks of concrete have been punched out. These are still grid-aligned breaks, not organic erosion.
- Floor tiles are offset or missing in patches, revealing dark gaps beneath. The gaps are rectangular holes, not organic pits.
- Debris is angular — shattered glass rendered as triangles, twisted metal as bent rectangles. Nothing in the environment is round.

**Why orthogonal + decay, not organic:**

1. **Pixel art efficiency.** Orthogonal geometry is trivially easy to tile and recombine at 16x16. Organic curves require unique per-tile work. For a 5-day MVP, grid-based is the only viable path.
2. **Contrast with interactive elements.** The round enemies and circular bullets become immediately visible against the angular world. If the environment were also organic/curved, characters would blend in.
3. **Emotional read.** A grid that has been damaged communicates "something went wrong here" more powerfully than a jungle or cave. The player feels they are in a ruined *civilization*, not a natural space. This reinforces the sci-fi ruins aesthetic.

**Structural exceptions (maximum 2 per room):**

- Pipes or cables may curve along one axis (horizontal or vertical, never diagonal). These are the only curved structural elements and serve as visual "breathing room" in an otherwise rigid space.
- Curved structural elements must be desaturated and never glow — they are decorative, not interactive.

### 3.4 UI Shape Grammar

**The UI is a distinct language that echoes, but does not mirror, the game world.**

UI elements borrow the world's angular geometry but invert its material rule. Where the world is "dark structure, bright interactive," the UI is **dark panel, bright text** — the same two-layer hierarchy, applied to information instead of space.

| UI Element | Shape | Rationale |
|---|---|---|
| **Health bar** | Rectangular, grid-aligned, horizontal | Mirrors the floor grid. Health is structural — it belongs to the world's geometry. The bar is always at the same vertical position, same width, so the player's peripheral vision tracks it without conscious effort. |
| **Ammo / ability icons** | Square with 1px rounded corners | The slight rounding is the only curvature in the UI and signals "this is interactive, this is a button." Sharp corners = read-only information. Rounded corners = clickable / activatable. |
| **Damage numbers** | Diagonal float, angular font | Numbers fly upward-right at 15 degrees, using the "pickup diagonal" from section 3.2. Damage is a reward signal — it gets the same diagonal visual treatment as items, reinforcing positive feedback. |
| **Boss HP bar** | Wider rectangle, centered, with angular notch markers | The notch markers (small triangles at 25%, 50%, 75%) are the only triangular UI elements. Triangles in UI = boss thresholds = danger zones. The player learns to dread the notch approaching. |
| **Room title / floor indicator** | Thin horizontal bar, text centered | Minimal, forgettable. Floor information is context, not action. It recedes visually. |
| **Pause / menu overlays** | Full-screen dark panel (80% opacity), centered buttons | The overlay darkens the game world beneath it, literally enacting "dark stage" on the UI layer. Buttons use the rounded-square interactive shape. |

**What the UI never does:**

- No circles in UI. Circles are reserved for enemy projectiles. A circular UI element would create false threat association.
- No diagonal panels or rotated containers. Diagonal = pickup. Diagonal UI would cheapen the relief signal.
- No glow on UI elements. Glow is reserved for in-world interactive objects. UI text uses solid neon color, no bloom.

**Emotional subtext:** The UI is a calm, orderly layer on top of a chaotic game. It says "information is available, you are in control." The moment the UI starts feeling chaotic (too many elements, too much motion), the player loses that feeling of control — and in a bullet hell, control is the entire fantasy.

### 3.5 Hero Shapes vs. Supporting Shapes

**Visual dominance hierarchy (from most to least attention-drawing):**

1. **Player character** — Angular, broad, upward-pointing. The only shape that "owns" its space. Always the brightest non-bullet element on screen.
2. **Enemy projectiles** — Circular, glowing, high-saturation. The primary threat. They must be the most visually urgent thing after the player.
3. **Enemies** — Round, moderate brightness. Visible but not screaming for attention. The player reads them as "source of bullets" rather than individual threats.
4. **Pickups** — Diagonal, bright, small. They pop because of diagonal rotation in an orthogonal world. The player notices them peripherally and gravitates toward them.
5. **Environment** — Dark, rectangular, static. Invisible until the player needs cover or navigation. The background exists to make everything else legible.

**The "eye path" principle:** In any room, the player's eye should follow this sequence: Player -> Bullets -> Enemies -> Pickups -> Exit. Shape language enforces this by giving each category a unique geometric vocabulary. The eye never gets confused about what it is looking at because no two categories share a shape.

**Supporting shape rule: "Boring on purpose."**

Environmental props (crates, barrels, broken furniture) must be the most visually generic objects in the game. They are rectangular, desaturated, and identical to each other within a room. This is deliberate — if a crate had a unique silhouette, the player would look at it, wonder if it was interactive, and lose reading time on actual threats. The boring-ness of props is a feature, not a limitation.

**Emotional subtext:** The player is the protagonist of every frame. Not because of a cutscene or a dramatic pose, but because the shape language of the entire game points at them and says "you are the most important thing here." This is the core of the "dark stage, bright actors" principle applied to geometry: the stage (environment) is structurally simple and dark, the actors (player, bullets, enemies) are geometrically distinct and bright, and the protagonist (Knight) is the most geometrically commanding shape in the scene.

## 4. Color System

### 4.1 Design Philosophy

Color in Bullet Knight is not decoration -- it is the primary information channel. At 16x16 sprite sizes with 50+ bullets on screen, color is faster to read than shape, size, or animation. Every hue in the palette carries a single, unambiguous semantic meaning. The player never has to ask "what color is danger?" because danger is always one color, everywhere, every time.

The palette is governed by the same constraint as the rest of the art bible: **"Less than four."** Each screen uses a maximum of three neon hues plus the black/gray structural layer. This keeps pattern recognition fast and cognitive load low -- the core requirement for a bullet hell that feels爽 rather than chaotic.

### 4.2 Primary Palette

| # | Name | Hex | Role | Category |
|---|------|-----|------|----------|
| 1 | **Neon Cyan** | `#00E5FF` | Player identity | Neon |
| 2 | **Neon Magenta** | `#FF00FF` | Enemy threat | Neon |
| 3 | **Neon Orange** | `#FF8800` | Reward / pickup | Neon |
| 4 | **Hot Pink** | `#FF69B4` | Boss escalation | Neon (reserved) |
| 5 | **Concrete Dark** | `#1A1A2E` | Background / walls | Structural |
| 6 | **Concrete Mid** | `#2D2D44` | Floors / debris | Structural |
| 7 | **Pure White** | `#FFFFFF` | Critical information | UI-only |

**Maximum simultaneous neon count: 3.** In standard rooms, only Cyan, Magenta, and Orange appear. Hot Pink is introduced exclusively during boss encounters, replacing one of the other three (usually Magenta, since the boss supersedes normal enemies). This ensures the "less than four" rule is never broken.

### 4.3 Semantic Color Assignments

Each color's meaning is anchored to a specific psychological or perceptual rationale, not arbitrary choice.

#### Neon Cyan (`#00E5FF`) -- "This is me."

**Semantic meaning:** Player agency, safety, control.

**What uses it:** Knight sprite tint/glow, player projectiles, player trail effects, friendly ability indicators.

**Why cyan for the player:**

1. **Luminance dominance.** At equal saturation, cyan has the highest perceived luminance of the three primary neons. This means the player is literally the brightest actor on screen at all times, directly enacting the "dark stage, bright actors" principle without requiring manual brightness adjustments per scene.
2. **Cool-warm opposition.** Cyan is the only cool-toned neon in the palette. All threats (magenta, orange, hot pink) are warm-toned. The player's eye learns to associate "cool = me, warm = not me" -- a pre-attentive distinction that requires zero conscious processing.
3. **Cultural resonance.** Cyan/electric blue is the dominant color of sci-fi hero interfaces (Tron, Ghost in the Shell, cyberspace aesthetics). It reads as "technology under my control" rather than "technology threatening me."

**Design constraint:** Player projectiles must always be Cyan. No exceptions. If a weapon or ability changes color, it is not a player weapon -- it is an environmental hazard or enemy variant.

#### Neon Magenta (`#FF00FF`) -- "This will hurt you."

**Semantic meaning:** Active threat, hostility, danger.

**What uses it:** Enemy sprites (tint/glow), enemy projectiles, enemy attack telegraphs, environmental hazards (lava, acid, traps).

**Why magenta for enemies:**

1. **Maximum hue opposition to cyan.** On the color wheel, magenta and cyan are ~180 degrees apart. This is the strongest possible contrast between two hues, ensuring enemies are never confused with the player even in dense bullet patterns. The player sees their cyan bullets cutting through a field of magenta -- the visual conflict is instant and unmistakable.
2. **Unnatural and aggressive.** Magenta does not occur in natural environments. It reads as artificial, wrong, hostile -- a color that "shouldn't be here." In a sci-fi ruins setting, this reinforces the idea that enemies are corrupted or invasive technology.
3. **Warm = danger convention.** Players universally associate warm reds/pinks with danger (fire, blood, warning signs). Magenta sits in this warm danger zone while remaining distinct from orange (reward) through its blue undertone.

**Design constraint:** All enemy projectiles must be Magenta. If an enemy fires orange or cyan projectiles, the color semantics break and the player cannot distinguish threat from reward or self. Enemy variants may modulate magenta's brightness (brighter = faster projectile, dimmer = slower) but never change its hue.

#### Neon Orange (`#FF8800`) -- "This is for you."

**Semantic meaning:** Reward, opportunity, relief.

**What uses it:** Pickup items (health, ammo, currency), reward screens, upgrade indicators, room-clear flash effects.

**Why orange for rewards:**

1. **Approach signal.** Environmental psychology and UX research consistently show warm orange/gold tones as "approach" signals -- they draw the player toward them rather than triggering avoidance. In a game where the player is constantly dodging magenta threats, orange pickups create a visual oasis: "this thing wants me to come closer."
2. **Warm but not dangerous.** Orange shares the warm family with magenta but lacks magenta's blue undertone. This makes it feel warm-and-safe rather than warm-and-threatening. The player learns: warm-pink = run, warm-orange = grab.
3. **Gold/treasure association.** Orange-yellow is the universal color of coins, gold, treasure, and reward across game culture (Sonic rings, Mario coins, Diablo gold). The association is pre-learned -- players do not need to be taught that orange things are good.

**Design constraint:** Orange must never be used for enemy projectiles or hazards. If a room needs a third neon for a hazard type, it must use a variant of magenta (brighter/darker) or hot pink (boss-only), never orange. Breaking this rule would make players hesitate before grabbing pickups -- the exact opposite of the intended "relief" response.

#### Hot Pink (`#FF69B4`) -- "This is the real danger."

**Semantic meaning:** Boss-level threat, escalation, dread.

**What uses it:** Boss sprite tint/glow, boss projectiles, boss attack telegraphs, boss HP bar, death countdown numerals.

**Why hot pink for bosses (and not just magenta):**

1. **Saturation escalation.** Hot Pink is brighter and more saturated than Neon Magenta. When the boss spawns and the palette shifts from magenta enemies to hot pink boss, the player perceives an escalation in intensity -- the color literally "turns up the volume." This is the visual equivalent of the camera pull-back in section 2.4: the boss is a bigger deal.
2. **Emotional specificity.** Magenta means "generic threat." Hot Pink means "specific, singular, personal threat." The hue shift communicates that this is not just more enemies -- this is THE enemy. The player's pattern recognition (magenta = dodge) upgrades to (hot pink = dodge everything, this is the real fight).
3. **Death screen integration.** The death countdown uses hot pink (section 2.5) to maintain emotional continuity: the boss's color follows you into death. This creates a Pavlovian association -- hot pink means "the thing that killed me" -- which heightens tension on the next boss encounter.

**Design constraint:** Hot Pink is the most restricted color in the palette. It must never appear in standard rooms, on regular enemies, or on pickups. Its power comes from rarity. If the player sees hot pink, a boss is present or they are dead. No other scenario.

#### Concrete Dark (`#1A1A2E`) -- "This is the world."

**Semantic meaning:** Environment, structure, permanence.

**What uses it:** Wall fills, background panels, ceiling recesses, darkest shadow areas.

**Why this specific dark:**

1. **Not pure black.** Pure black (`#000000`) creates an abyss effect -- the eye reads it as "nothing here" and skips it entirely. Concrete Dark is a very dark blue-gray that reads as a solid surface with depth. The player perceives walls as real objects, not empty space.
2. **Blue undertone.** The slight blue cast ties the structural layer to the game's sci-fi tech aesthetic. A warm brown-gray would read as "medieval dungeon." A cool blue-gray reads as "abandoned facility."
3. **Glow contrast.** When neon elements glow against Concrete Dark, the blue-gray absorbs and frames the glow cleanly. Against pure black, glows can appear overly bright or bleed visually. Against Concrete Dark, they look intentional.

#### Concrete Mid (`#2D2D44`) -- "This is the ground."

**Semantic meaning:** Traversable space, floor, debris.

**What uses it:** Floor tiles, broken furniture, rubble, pipe/cable backgrounds.

**Why a separate floor color:**

1. **Spatial orientation.** The player must instantly distinguish walls (impassable) from floor (walkable) without reading geometry. The brightness gap between Concrete Dark (walls) and Concrete Mid (floor) creates this distinction -- darker = blocked, lighter = walkable.
2. **Tile readability.** At small pixel sizes, floor tiles need enough contrast against walls to be individually readable as a grid. Concrete Mid against Concrete Dark provides just enough contrast (approximately 15% brightness difference) to see the grid without it becoming visually noisy.

#### Pure White (`#FFFFFF`) -- "Read this now."

**Semantic meaning:** Critical numerical information, text, UI chrome.

**What uses it:** Damage numbers, health/ammo counters, text labels, boss HP bar fill, button text.

**Why white for information:**

1. **Universal information color.** White text on dark backgrounds is the most readable combination in existence. In a game where the player is tracking HP, ammo, and combo count while dodging bullets, information must be instantly legible. White achieves this with zero ambiguity.
2. **Non-semantic.** White does not mean "player" or "enemy" or "reward." It means "information." This separation prevents confusion -- a white number floating above an enemy is damage, not a pickup. A white bar is the boss's HP, not a health item.
3. **Glow prohibition.** White in the UI layer never glows. Glow is reserved for in-world interactive elements (section 3.4). This maintains the separation between "the game world" (glowing neons) and "the information layer" (flat white text).

### 4.4 Per-State Color Temperature Rules

The palette shifts between two temperature states to communicate game intensity. The player should feel the temperature change before they consciously register what changed.

#### Cool State (Exploration / Room Clear)

| Property | Value | Purpose |
|----------|-------|---------|
| Background brightness | 40-50% of max | Readable but subdued |
| Neon saturation | 60-80% | Present but not aggressive |
| Glow radius | 1-2px halo | Subtle, atmospheric |
| Ambient light | Cool blue-white (6500K equivalent) | Clinical, calm |
| Particle density | Low (3-8 ambient dust) | Breathing room |
| Screen vignette | None | Open, relaxed |

**Visual effect:** The room feels like a dimly lit corridor. The player's cyan bullets and the room's geometry are clearly visible, but nothing is screaming for attention. This is the "inhale" between combat "exhales."

#### Hot State (Combat / Boss / High Combo)

| Property | Value | Purpose |
|----------|-------|---------|
| Background brightness | 55-65% of max (slightly brighter) | Ambient feels warmer |
| Neon saturation | 90-100% | Full intensity |
| Glow radius | 3-4px halo | Explosive, energetic |
| Ambient light | Warm tint (shift 2-5% toward orange) | Urgency without awareness |
| Particle density | High (15-25 combat sparks) | Density = intensity |
| Screen vignette | None (normal combat) / Pulsing magenta (low HP) | Danger escalation |

**Visual effect:** The room feels like it's on fire. Every bullet is a light source at full brightness, the player's screen is literally brighter than during exploration, and the warm ambient tint makes everything feel more urgent. This is the "exhale" -- the room is alive with danger.

#### Boss State (Maximum Hot)

| Property | Value | Purpose |
|----------|-------|---------|
| Background brightness | 50% (darkens to let boss glow dominate) | Boss is the star |
| Neon saturation | 100% | Full power |
| Glow radius | 4-6px halo on boss | Intimidating presence |
| Ambient light | Magenta-tinted (shift 2-3% toward magenta) | Pre-associates with boss palette |
| Particle density | High + unique boss particles | Escalation |
| Screen vignette | Pulsing hot pink at 25%/50%/75% HP thresholds | Dread milestones |

**Visual effect:** The boss owns the room. Its hot pink glow dominates the visual field, the ambient has shifted to match its color temperature, and the pulsing vignette at HP thresholds creates a rhythm of dread. The player is no longer in "combat" -- they are in "survival."

#### Temperature Transition Timing

| Transition | Duration | Method |
|------------|----------|--------|
| Cool to Hot (enemy spawn) | 0.3s | Ambient warmth ramp + saturation increase |
| Hot to Cool (room clear) | 0.5s | Ambient cool-down + saturation decrease |
| Any to Boss | Instant (1 frame) | Hard cut to boss ambient + hot pink vignette |
| Boss to Cool (boss death) | 0.8s | Slow saturation drain + flash to full color |

The cool-to-hot transition is fast (0.3s) because the player needs to feel urgency immediately when threats appear. The hot-to-cool transition is slower (0.5s) to let the relief wash over the player -- this is the "reward" of clearing a room. The boss transition is instant because there is no gradual escalation into a boss fight -- the boss appears, and the world changes.

### 4.5 UI Palette

The UI uses the same neon colors as the world but introduces additional structural colors for panel backgrounds and text hierarchy. This divergence is explicit and intentional: the UI needs to be readable as an information overlay, not as part of the game world.

#### HUD Colors (In-Game Overlay)

| Element | Color | Rationale |
|---------|-------|-----------|
| Health bar fill | Neon Cyan | Ties health to the player's identity -- "this is MY health" |
| Health bar background | Concrete Dark | Recessed, structural, non-interactive |
| Ammo / ability cooldowns | Neon Cyan (dimmed to 60%) | Same family as health, lower priority |
| Combo counter | Neon Orange | Combo is a reward signal -- warm, encouraging |
| Boss HP bar fill | Hot Pink | Matches boss color -- "this is its health, it's a lot" |
| Boss HP bar background | Concrete Dark | Same recessed treatment as player health |
| Boss HP bar threshold notches | Pure White | High contrast against hot pink, reads as "milestone" |
| Damage numbers (player dealing) | Pure White | Neutral information -- not tied to any entity's color |
| Damage numbers (player receiving) | Hot Pink | "You are taking damage from the boss/threat" |
| Room clear flash | Neon Orange | Reward pulse -- the room rewards you with warmth |
| Low HP vignette | Hot Pink (pulsing) | Escalation -- the danger color is closing in |

#### Menu Colors (Non-Gameplay Screens)

| Element | Color | Rationale |
|---------|-------|-----------|
| Panel background | `#0D0D1A` (near-black) | Darker than gameplay backgrounds -- menus are not "the world" |
| Panel border | Concrete Mid | Subtle structural framing |
| Primary button fill | Neon Cyan | "Start, continue, confirm" -- player agency color |
| Primary button text | Pure White | Maximum readability |
| Secondary button fill | Concrete Mid | Lower priority, non-committal actions |
| Secondary button text | Neon Cyan (dimmed) | Reads as "optional" |
| Title / header text | Neon Cyan | Brand color for the game's identity |
| Body text | `#B0B0C0` (soft gray) | Readable on dark backgrounds without competing with neons |
| Disabled state | Concrete Mid (all text) | Visually "off" -- desaturated, low contrast |
| Hover / selection highlight | Neon Cyan (glow halo) | Interactive elements use the player's color -- "you are in control" |

**Key divergence from world palette:** Menus introduce `#0D0D1A` and `#B0B0C0` -- two colors that never appear in gameplay. This creates a clear visual boundary: when the screen uses these colors, the player is in a menu, not in the game. The boundary is reinforced by the complete absence of neon magenta and neon orange in menus (no enemies, no pickups -- just the player making choices).

**What the UI never does (color edition):**

- No neon magenta in HUD or menus. Magenta means "enemy threat." The UI is never threatening.
- No neon orange in health bars. Orange means "pickup/reward." Health is not a reward -- it is a right.
- No gradient fills on any UI element. Gradients are a third visual language that would compete with the two established languages (flat neon, flat structural). Flat color only.
- No transparency below 80% opacity on UI panels. The UI must be fully opaque to maintain the "information layer" separation from the game world beneath it.

### 4.6 Colorblind Safety

The three-neon palette creates potential confusion for colorblind players. The following analysis maps every problematic color pair and specifies the required backup cues.

#### Pair Analysis

| Color Pair | Normal Vision | Protanopia (Red-Blind) | Deuteranopia (Green-Blind) | Tritanopia (Blue-Blind) | Risk Level |
|------------|---------------|----------------------|---------------------------|------------------------|------------|
| **Cyan vs. Magenta** (Player vs. Enemy) | Blue-green vs. Pink-purple — high contrast | Blue vs. Pink-purple — still distinct | Blue vs. Pink-purple — still distinct | Both shift toward blue-pink — **low contrast** | **MEDIUM** (tritanopia only) |
| **Magenta vs. Orange** (Enemy vs. Pickup) | Pink vs. Orange — clear | Both shift toward yellow-green — **very low contrast** | Both shift toward yellow-green — **very low contrast** | Pink-purple vs. Orange — still distinct | **HIGH** (protanopia + deuteranopia) |
| **Hot Pink vs. Magenta** (Boss vs. Regular Enemy) | Bright pink vs. Deep pink — same hue family | Both shift toward yellow — **low contrast** | Both shift toward yellow — **low contrast** | Both shift toward blue — **low contrast** | **HIGH** (all types) |
| **Cyan vs. Orange** (Player vs. Pickup) | Blue-green vs. Orange — high contrast | Blue vs. Yellow — high contrast | Blue vs. Yellow — high contrast | Blue-green vs. Orange — still distinct | LOW |
| **Cyan vs. Hot Pink** (Player vs. Boss) | Blue-green vs. Bright pink — high contrast | Blue vs. Bright yellow — high contrast | Blue vs. Bright yellow — high contrast | Blue-green vs. Blue-pink — moderate | LOW |

#### Required Backup Cues

Every color pair rated MEDIUM or HIGH above must have redundant non-color cues. These are not optional accessibility features -- they are required for the game to be playable by colorblind users.

**Magenta vs. Orange (Enemy vs. Pickup) -- HIGH RISK:**

| Cue Type | Enemy (Magenta) | Pickup (Orange) |
|----------|----------------|-----------------|
| **Shape** | Round body, no protrusions | Diamond / 4-point star (section 3.2) |
| **Motion** | Moves toward player or tracks player | Static or slow bobbing (no pursuit) |
| **Sound** | Continuous hum / threat audio | Chime / positive audio sting |
| **Glow behavior** | Steady glow, constant intensity | Pulsing glow, rhythmic (heartbeat-like) |
| **UI icon** | Skull or cross icon in bestiary | Heart or diamond icon in inventory |

The shape difference alone should be sufficient for most players (round vs. star), but the motion cue is the strongest backup: enemies move, pickups do not. A colorblind player can distinguish "things chasing me" from "things sitting still" regardless of color.

**Hot Pink vs. Magenta (Boss vs. Regular Enemy) -- HIGH RISK:**

| Cue Type | Regular Enemy (Magenta) | Boss (Hot Pink) |
|----------|------------------------|-----------------|
| **Size** | 16x16 to 24x24 pixels | 48x48 to 64x64 pixels minimum |
| **Shape** | Round, symmetrical | Irregular, asymmetric, with protrusions (section 3.2) |
| **Screen position** | Scattered, multiple instances | Singleton, centered or dominant |
| **Boss HP bar** | None | Full-width bar at top of screen with threshold notches |
| **Camera behavior** | No change | Pull-back 5% on spawn (section 2.4) |
| **Audio** | Standard enemy sounds | Unique boss entrance sting + music shift |
| **Vignette** | None | Pulsing screen-edge effect at HP thresholds |

Size is the primary backup cue. A 48x48+ pixel entity on screen cannot be confused with 16x16 enemies regardless of color. The boss HP bar is a secondary structural cue: a full-width bar appearing at the top of the screen means "boss fight" in any color.

**Cyan vs. Magenta (Player vs. Enemy) -- MEDIUM RISK (tritanopia only):**

| Cue Type | Player (Cyan) | Enemy (Magenta) |
|----------|---------------|-----------------|
| **Shape** | Angular, broad shoulders, upward triangle (section 3.2) | Round, stubby, no protrusions |
| **Motion** | Controlled by player input (predictable pathing) | AI-driven (predictable pattern but not player-controlled) |
| **Projectile shape** | Short bar / rectangular | Perfect circle (section 3.2) |
| **Screen position** | Always visible, central camera focus | Appears from edges or spawns in room |
| **Health bar** | Always on screen (player HUD) | Only on boss |

Shape is the primary backup. Angular vs. round is detectable even at 6x6 pixel sizes (section 3.2's 3-pixel rule). Projectile shape (bar vs. circle) is a secondary cue that works even in dense bullet patterns.

#### Implementation Priority

For a 5-day MVP, the backup cues should be implemented in this order:

1. **Shape distinction** (already required by section 3.2 -- no additional work)
2. **Motion distinction** (enemies pursue, pickups bob -- already in enemy AI spec)
3. **Size distinction for boss** (already required by shape language -- no additional work)
4. **Boss HP bar** (structural cue -- implement with boss fight)
5. **Sound cues** (enemy hum vs. pickup chime -- implement with audio pass)
6. **Glow behavior differentiation** (steady vs. pulsing -- implement with VFX pass)

Items 1-4 are zero-cost (already part of the design). Items 5-6 require audio/VFX work that should be scheduled if time permits. The game is playable for colorblind users based on cues 1-4 alone.

---

*Sections 5-9 (Character Design, Environment, UI, Asset Standards, References) will be added in future iterations.*
