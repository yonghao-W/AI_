# K · 战斗代码解耦（近战 / 命中 / HUD）

- 起点：`f014dda`（近战特性提交后的 HEAD）
- 本轮：`734617d` → `d9db9e7`，共 6 个可回退提交
- 范围：只处理近战状态、第三人称表现、命中请求和 HUD 同步；未改设置、菜单、城市生成、资产和任务数值。

## 1. 审计基线（改前）

| 模块 | 规模 | 主要职责 | 关键耦合 |
|---|---|---|---|
| `player.gd` | 1378 行 / 82 状态 / 64 函数 | 移动、相机、枪械、近战状态、第三人称骨架、近战姿态、命中请求、自动驾驶 | 通过 `main_ref.call("request_zombie_hit", ...)` 字符串调用 Main；近战状态和视觉混在一起 |
| `main.gd` | 2729 行 / 167 函数 | 编排、网络、任务、UI 同步、CLI 截图 | 286 处直接引用 `player/hud/menu`；每帧传 6 个 HUD 位置参数 |
| `game_hud.gd` | 1822 行 / 81 函数 | HUD、覆盖层、暂停、结算、设置应用 | `set_ammo()` 已扩到 6 个位置参数；近战连击阶段靠新增参数传入 |
| `melee_combo_state` | 不存在 | — | 阶段/窗口/缓存/命中帧全部在 Player 内 |
| `melee_rig_view` | 不存在 | — | 骨架与姿态在 Player 内 |
| `CombatHudState` | 不存在 | — | Main 直接调多个 setter |

**已确认无效状态**

- `_melee_weapon_id`：只在 `_build_tp_weapon()` 写入，运行时无读取。
- `_melee_stage_damage`：只在 `_start_melee_stage()` 写入；实际伤害由 `main.gd` 服务器路径按 `combo_stage` 乘 `WeaponCatalog.melee_stage_damage()`，测试也只是读这个内部值。

**实际调用路径（改前）**

```
Player._resolve_melee_hit()
  -> main_ref.has_method("request_zombie_hit")
  -> main_ref.call("request_zombie_hit", zid, false, weapon_id, stage)
  -> Main.request_zombie_hit()
  -> _server_apply_hit() / rpc_id("_net_request_hit")

Main._process()
  -> GameHUD.set_ammo(mag, reserve, reloading, progress, melee, combo_stage)
```

## 2. 改后模块边界

```
WeaponCatalog ── 数据：阶段时长/命中点/倍率/范围/扇形/冲刺
      │
MeleeComboState ── 纯逻辑：阶段、窗口、缓存、命中帧、取消
      │
LocalPlayer ── 输入、移动、命中目标查询；emits zombie_hit_requested
      │                         │
      │                         └──> Main._on_local_zombie_hit -> RPC / 服务器校验 / 伤害
      │
MeleeRigView ── 视觉：骨架、武器模型、姿态、拔刀、相机冲击；无伤害/网络逻辑

Main ── 每个角色快照写入 CombatHudState
          -> GameHUD.apply_combat_state(state)
          -> 只在字段变化时调用兼容 setter
```

**公开接口（新）**

- `MeleeComboState.begin(duration, contact_fraction, stage)` / `tick(delta)` / `buffer_attack()` / `next_stage()` / `cancel()`
  - 事件字段：`hit_this_tick`、`hit_stage`、`chain_requested`、`finished_this_tick`、`reset_this_tick`
  - 不依赖场景树、HUD、Camera3D、网络或 Player。
- `MeleeRigView.equip(id)` / `update_pose(...)` / `trigger_hit(stage)` / `refresh_visibility(...)` / `camera_offset()`
  - 不决定伤害、命中合法性或网络状态。
- `LocalPlayer.zombie_hit_requested(zid, headshot, weapon_id, combo_stage)` 信号。
- `CombatHudState` 字段：`health/max_health/weapon_*/mag/reserve/reloading/reload_progress/melee/combo_stage/carrying_core/downed`。
- `LocalPlayer.write_hud_state(state)` 写快照；`GameHUD.apply_combat_state(state)` 读快照。
- 兼容层保留：`set_health`、`set_ammo`（含旧 6 参数）、`set_weapon_strip`、`request_zombie_hit`、4 参数 RPC。

## 3. 提交与文件

| 提交 | 内容 | 主要文件 |
|---|---|---|
| `734617d` | 清理 `_melee_weapon_id` / `_melee_stage_damage`，测试改查 WeaponCatalog | `player.gd`、`test_melee_combo.gd` |
| `1e9a414` | 提取纯 `MeleeComboState`；死亡/复活/搬运取消 | `melee_combo_state.gd`、`player.gd`、`test_melee_combo_state.gd` |
| `af36ee8` | 提取 `MeleeRigView`；Player 只应用相机偏移 | `melee_rig_view.gd`、`player.gd` |
| `3adef2f` | 类型化命中信号；移除 `main_ref` 字符串调用 | `player.gd`、`main.gd`、`weapon_catalog.gd`、`test_melee_combo.gd` |
| `151619d` | `CombatHudState` + `apply_combat_state`；Main 复用快照 | `combat_hud_state.gd`、`game_hud.gd`、`main.gd`、`test_hud_state.gd` |
| `d9db9e7` | 服务器在目标查询前拒绝非法近战阶段 | `main.gd`、`test_hit_validation.gd` |

Diff 总量（`b929354..HEAD`，仅 scripts/tests）：11 个文件，+869 / -272；`player.gd` 从 1378 行降到 1212 行，成员状态 82→64。`main.gd` 2744 行、`game_hud.gd` 1863 行，体量基本未减，仍承担编排和覆盖层职责。

## 4. 回归结果（本机实际）

| 项目 | 结果 |
|---|---|
| 纯连击状态 | 26 / 0 |
| 近战集成（阶段、缓存、超时、死亡、搬运、视图显隐） | 35 / 0 |
| HUD 快照与兼容层 | 21 / 0 |
| 服务器非法阶段 | 4 / 0（mock 证明非法阶段不触发目标查询/伤害） |
| 设置 V2 | 106 / 0 |
| UI 集成 | 105 / 0 |
| 任务 | 150 / 0 |
| 城市 | 18 / 0 |
| 第一章 | 230 / 0 |
| 资产 | 7 / 0 |
| 显示矩阵 | 120 / 0，8 条 zoom 压力 warning |
| 4 人联机 UI | HOST 23 / 3×CLIENT 19，0 |
| 章节联机（2 人） | 双端 station_spawn=true |
| 视觉矩阵（旧基线对比） | 52 张，0 超阈值 0.15%；最差菜单 0.0921% |
| 真实输入近战截图对比 | 4 个姿态，像素变化 ≤0.12%；下劈/大锤帧为 0 |

验证方式：在主场景里通过真实 `Input` 点击链路打三连击并截图，不是只调用状态机。对照图在 `shots/refactor_before/`、`shots/refactor_after_*/`。

## 5. 新增一个近战动作的影响面

用现有三段结构新增一把刀/斧头：

1. `WeaponCatalog.WEAPONS` 增加数据（名称、间隔、范围、扇形、倍率入口）。
2. 如需不同挥砍轮廓，只在 `MeleeRigView._stage_pose()` 增加姿态分支。
3. 命中仍走 `zombie_hit_requested`，服务器仍按阶段校验。

**不再需要**修改 Player 的移动/相机核心、Main 的每帧 HUD 位置参数、GameHUD 的 `set_ammo` 参数列表。若增加第四段或改变阶段数，需要改 `MeleeComboState`/配置与 HUD 的显示常量，但仍不改 Main 的 UI 同步参数。

## 6. 未验证 / 保留耦合

- 真实玩家手感、长时间连招舒适度、真实手柄、OS 级 DPI、最低规格硬件、真实 WAN、4 人故障网络未验证。
- 服务器拒绝非法阶段是方法级 + mock 测试；没有从真实 ENet 客户端注入非法阶段。
- `main.gd` 仍是 2744 行/169 函数的大编排类；HUD 的情报/背包/抽卡/暂停/结算覆盖层仍在同一个 1863 行类里。
- `UISettings` 的旧属性兼容层保留，属于迁移成本而非本轮债务。
- 未建立 MVVM/ECS/大型事件总线；这是有意控制改动规模。

## 7. 后续候选（未做）

1. 拆分 `GameHUD` 覆盖层（情报/背包/抽卡/暂停/结算）为独立场景或组件。
2. 拆分 `main.gd` 的比赛编排、网络、CLI 取证三条路径。
3. 为近战命中查询单独建 `MeleeHitResolver`，让 Player 再减少命中候选代码。
4. 增加真实网络层的非法参数注入测试。

## 8. 回退

- 任一提交可单独 revert；接口兼容层在 `d9db9e7` 仍保留，回退 HUD 快照不会立刻破坏旧测试。
- 全量回退到本轮前：`git reset --hard f014dda`（会丢弃本轮提交，仅限确认后使用）。
- 运行回归：`test_melee_combo_state.gd`、`test_melee_combo.gd`、`test_hud_state.gd`、`test_hit_validation.gd`，再跑设置/UI/任务/显示/联机。
