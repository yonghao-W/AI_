# A · 工程证据与架构审计

> 证据等级说明见 [README](README.md)。本文件中的“事实”均标注来源；推断会明确写为“推断”。
> 审计对象：`c805ed5`，Godot 4.7.2，1280×720 基准视口。

## 1. 结论摘要

现有 UI 的主要问题不是“缺少页面”，而是以下五件事同时成立：

1. **布局没有内容驱动的尺寸**：HUD 面板用固定像素矩形摆放，但 `PanelContainer` 会按内容最小尺寸撑大，导致面板越界和互相遮挡。
2. **没有真正的输入层**：移动、射击、开镜、UI 导航全部依赖物理键/鼠标硬编码；`project.godot` 没有 `[input]`，没有手柄映射。
3. **没有可见焦点**：全局 Theme 的 `focus` 样式是 `StyleBoxEmpty`；抽卡、军械库、背包卡片还显式禁用了焦点。
4. **信息常驻过多、按需信息不足**：战斗底部 11px 操作提示永远常驻，搬运核心时武器面板仍显示“就绪”，世界内 Label3D 与 HUD 同时提示同一个交互。
5. **视觉表现与业务状态耦合在三个大脚本里**：`main.gd` 2,514 行、`game_hud.gd` 1,509 行、`main_menu.gd` 809 行；所有节点、样式、布局、状态文案都在代码里即时创建，无法用场景/主题资源做视觉迭代。

## 2. 版本、入口与资源事实

### 2.1 工程配置（STATIC_VERIFIED）

来自 `project.godot`：

| 键 | 值 |
|---|---|
| `run/main_scene` | `res://scenes/main.tscn` |
| `config/features` | `PackedStringArray("4.7", "Forward Plus")` |
| `display/window/size/viewport_width/height` | 1280 / 720 |
| `display/window/size/window_width_override/height_override` | 1280 / 720 |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `expand` |
| `[input]` | **不存在**；没有任何自定义动作或手柄映射 |

### 2.2 资源清单（STATIC_VERIFIED）

- `scenes/` 只有 `main.tscn` 一个场景。
- 全工程 `.tscn` = 1，`.tres` = 0。
- `scripts/` 下 20 个 GDScript，共 10,087 行；另有 3 个测试脚本和 1 个预览脚本，总计 24 个 `.gd`。
- 没有任何 UI 场景、Theme 资源、字体资源或图标资源；字体由 `SystemFont` 运行时创建。
- UI 相关脚本规模：

| 文件 | 行数 | 角色 |
|---|---:|---|
| `scripts/main.gd` | 2,514 | 游戏/网络/任务/UI 编排 |
| `scripts/game_hud.gd` | 1,509 | 战斗 HUD 与全部覆盖层 |
| `scripts/player.gd` | 1,149 | 玩家移动/武器/输入 |
| `scripts/main_menu.gd` | 809 | 主菜单、大厅、军械库 |
| `scripts/mission_site.gd` | 609 | 世界内 Label3D 提示 |
| `scripts/menu_backdrop.gd` | 159 | 菜单全屏 `_draw` 背景 |
| `scripts/minimap.gd` | 125 | 小地图 `_draw` |
| `scripts/weapon_catalog.gd` | 121 | 武器数据与数值文案 |
| `scripts/ui_theme.gd` | 95 | 运行时 Theme/颜色/按钮样式 |
| `scripts/crosshair.gd` | 57 | 准星 `_draw` |
| `scripts/damage_vignette.gd` | 44 | 受伤暗角 `_draw` |

### 2.3 实际入口

`main.tscn` → `main.gd` → `_ready()` → `_build_ui()`（`main.gd:119`）：

1. 创建 `CanvasLayer "UI"`，`process_mode = ALWAYS`。
2. `MainMenu.new()`、`GameHUD.new()` 直接实例化，铺满全屏。
3. 在 `main.gd` 里集中连接 9 个菜单信号、5 个 HUD 信号、5 个网络信号、4 个玩家信号。
4. 初始 `hud.visible = false`，鼠标可见。

没有 UI 场景入口，也没有 `@onready` 节点绑定；所有 UI 节点都在 `_build()` 中以代码创建。

## 3. 节点组织与信息架构

### 3.1 MainMenu（`main_menu.gd`）

`_ready()` 设置 Theme、铺满、调用 `_build()`；`_build()` 创建：

- `MenuBackdrop`：全屏自绘天空、月亮、天际线、雾、46 个灰烬粒子、角标；`_process` 每帧推进粒子并 `queue_redraw()`。
- 外层 `MarginContainer`：左 62 / 上 34 / 右 26。
- 左列（比例 1.35）：
  - 品牌区：`死城突围 / DEAD CITY / 随机城市...`
  - 部署终端：呼号 `LineEdit`、种子 `LineEdit`、IP `LineEdit`、端口 `LineEdit`、创建/加入/单人按钮、状态行、局域网红字提示。
  - 局外档案：行动/完成/最佳战力/信用点、上次行动、血脉等级、军械库按钮。
  - 退出按钮。
- 右列（最小宽 352）：行动简报面板，固定 4 条玩法说明、颜色识别图例、操作列表、底部提示。
- 覆盖层：军械库（全屏 tint + 居中面板 + 7 张武器卡）、大厅（居中面板 + 4 行队伍 + 准备/开始/离开）。
- 没有 `ScrollContainer`；只有 Label 自动换行。

关键事实（STATIC_VERIFIED）：

- 军械库卡片 `focus_mode = Control.FOCUS_NONE`（`main_menu.gd` 约 424 行附近），键盘/手柄无法逐卡导航。
- 大厅客户端准备按钮在本地先翻转 `_lobby_local_ready` 并改按钮文案，再发请求；服务器确认通过 `update_lobby` 回填。没有“请求中”状态。
- 房主 1 人时 `all_ready = true`，底部显示“全员已准备，等待房主开始行动”，同时 3 个空槽显示“等待队员加入…”，文案互相矛盾（见 `lobby_host_1280x720.png`）。

### 3.2 GameHUD（`game_hud.gd`）

`_build()` 创建并 `_place()` 以下面板（固定锚点 + 固定像素矩形）：

| 面板 | 目标矩形（1280×720 逻辑） | 锚点 |
|---|---|---|
| 小队 | `(22, 18, 278, 164)` | 左上 |
| 行动目标 | `(22, 190, 278, 152)` | 左上 |
| 街区压力 | `(-178, 18, 356, 94)` | 上中 |
| 战术地图 | `(-238, 18, 216, 262)` | 右上 |
| 生命体征 | `(22, -116, 312, 96)` | 左下 |
| 弹药 | `(-290, -116, 268, 96)` | 右下 |
| 装备栏 | `(-290, -222, 268, 96)` | 右下 |
| 交互提示 | `(-220, -76, 440, 38)` | 下中 |
| 击杀信息 | `(-356, 292, 334, 170)` | 右上下方 |
| 波次横幅 | `(-380, 128, 760, 88)` | 上中 |

覆盖层：战术情报 940×488、战术背包 960×500、核心抽卡 896×448、暂停 460×320、任务结束 600×380、倒地/加载。

面板统一用 `_hud_panel()`：底色 `Color(0.043, 0.062, 0.072, 0.87)`，边框 `Color(0.22, 0.35, 0.37, 0.5)`，内边距 12/9。

**实际尺寸与目标不一致（HARNESS_VERIFIED）**：

- 小队面板目标 164，4 人时实际 **243**；与行动目标面板重叠 **71 逻辑像素**（1280×720：19,738 px²；1920×1080：44,410 物理 px²）。第 4 行 `K-7` 位于任务面板下方，被任务面板遮住；在 1920 截图中还能透过 0.87 透明度看到 `K-7` 和血条。
- 生命面板目标 96，实际 **121**；底部锚点从 y=604 向下长到 y=725，**在所有目标分辨率都越出底边 5 逻辑像素**（1920×1200 时为 7.5 物理像素）。

### 3.3 世界内提示（`mission_site.gd`）

`_label3d()` 创建带描边的 `Label3D`，内容包括：

- `安全区 · SAFE ZONE`
- `感染者不会进入`
- `核心交付台 [E]`
- `核心储藏层 B1\n沿坡道下行`
- `核心储藏层 · B1`
- `上行坡道 · 返回地表`
- `弹药补给台 [E]`

这些提示与 HUD 底部交互提示重复。实测截图中 `弹药补给 [E]` 占据屏幕中央视野，HUD 同时显示 `E 补充弹药`；`安全区 · SAFE ZONE` 位于右侧，和 HUD 任务面板的“基地安全区”重复。

## 4. 信号、数据源与状态依赖

### 4.1 MainMenu 信号

| 信号 | 参数 | 由谁处理 |
|---|---|---|
| `host_requested` | name, port, seed | `main._on_host_requested` |
| `join_requested` | name, address, port | `main._on_join_requested` |
| `solo_requested` | name, seed | `main._on_solo_requested` |
| `quit_requested` | — | `main._on_quit_requested` |
| `lobby_ready_requested` | ready | `main._on_lobby_ready_requested` |
| `lobby_start_requested` | — | `main._on_lobby_start_requested` |
| `lobby_leave_requested` | — | `main._on_lobby_leave_requested` |
| `buy_weapon_requested` | weapon_id | `main._on_buy_weapon_requested` |
| `equip_weapon_requested` | weapon_id | `main._on_equip_weapon_requested` |

### 4.2 GameHUD 信号

| 信号 | 参数 | 由谁处理 |
|---|---|---|
| `resume_requested` | — | `main._resume_game` |
| `lobby_requested` | — | `main._on_lobby_requested` |
| `card_picked` | index | `main._on_card_picked` |
| `draw_cancelled` | — | `main._on_draw_cancelled` |
| `weapon_selected` | weapon_id | `main._on_backpack_weapon_selected` |

### 4.3 数据来源与更新节奏

| UI 块 | 数据来源 | 更新方式 |
|---|---|---|
| 生命 | `player.health_changed` → `hud.set_health` | 事件驱动 |
| 弹药/准星扩散/小地图/任务 | `player.mag/reserve/reloading`、`player.global_position`、任务状态 | **每帧**（`main.gd:747-750`） |
| 波次/得分/小队 | 服务器 summary | 每 0.25s（`SUMMARY_INTERVAL`）；网络 summary 另走 `_net_summary` |
| 交互提示 | `_update_mission_hud()` 每帧计算 | 每帧 `set_interaction` |
| 武器栏 | `player.loadout_summary()` / `weapon_profile()` | 切换/开始/复活时 |
| 主菜单档案 | `MetaProfile` | `set_profile` / 军械库操作后 |
| 大厅 | `_lobby_payload` / 网络广播 | `update_lobby` |
| 抽卡 | `_draw_options` | 打开时构建 3 张卡 |
| 小地图 | 城市布局、远端玩家、丧尸、任务标记 | 每帧 `update_entities` + `queue_redraw` |

### 4.4 客户端请求 vs 服务器确认

- 准备：客户端本地先翻转按钮文案 → `rpc_id(1, "_net_lobby_ready")` → 服务器更新字典并广播 → `update_lobby` 回填。**没有 pending 态**；网络慢时按钮会短时显示本地状态。
- 抽卡：客户端 `rpc_id(1, "_net_pick_card")`；服务器 `_server_pick_card` 决定结果并广播。HUD 只发信号，不直接改状态，边界正确。
- 背包切枪：本地 `player.switch_weapon_slot()`；失败时 HUD 提示“搬运核心或换弹时无法切换武器”。这是本地即时反馈，不涉及网络权威。
- 军械库购买/装备：单机局外数据，`MetaProfile` 直接修改并持久化；`game_started` 时拒绝。

### 4.5 暂停与鼠标

`main._pause_game()`（806）：

- 单人：`get_tree().paused = true`。
- 联机：**不暂停场景树**，只 `player.set_input_enabled(false)` 并释放鼠标；HUD 文案明确“战斗仍在服务器上继续”。
- 打开情报/背包：`_set_overlay_input(false)`，禁用玩家输入、释放鼠标。
- 关闭：恢复输入并重新捕获鼠标。
- 联机暂停时玩家是否仍会受到伤害、倒地，代码路径存在但未做真实联机验证，标为 **UNVERIFIED**。

## 5. 样式、动效、焦点与输入

### 5.1 样式硬编码（STATIC_VERIFIED）

| 位置 | `add_theme_*` 次数 | `Color(` 次数 |
|---|---:|---:|
| `game_hud.gd` | 97 | 105 |
| `main_menu.gd` | 59 | 40 |
| `ui_theme.gd` | 7 | 30 |
| `minimap.gd` | 0 | 23 |
| `mission_site.gd` | 0 | 67 |
| `crosshair.gd` | 0 | 6 |

- `DeadCityUI` 定义了 12 个语义色 + 4 个玩家色，但大量地方直接写 `Color(...)` 或十六进制，语义色并未被强制使用。
- `display_font()` 每次调用都 `SystemFont.new()`；`minimap._draw()` 每帧调用一次。
- 没有字号、行高、间距、圆角、面板透明度的 token 层；所有数值散落在构建代码里。

### 5.2 焦点

- `make_theme()`：`theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())`。
- `style_button()` 覆盖 normal/hover/pressed/disabled，但**不设置 focus**。
- 离屏审计统计（HARNESS_VERIFIED）：
  - 主菜单 5 个按钮：5 个“焦点不可见”。
  - 大厅 7 个按钮：7 个“焦点不可见”。
  - 军械库 13 个按钮：13 个“焦点不可见”，7 张卡片 `FOCUS_NONE`。
  - 抽卡 4 个按钮：4 个“焦点不可见”，3 张卡片 `FOCUS_NONE`。
  - 背包 3 个按钮：3 个“焦点不可见”，2 张卡片 `FOCUS_NONE`。
  - 情报/暂停/任务结束各有 1–2 个“焦点不可见”按钮。
- 主菜单打开时没有调用 `focus_name()`；键盘用户需要先按 Tab，且看不到焦点在哪。

### 5.3 输入

- `main._unhandled_input()` 直接比较 `physical_keycode`：`TAB`、`B`、`E`、`G`、`ESC`、抽卡 `1/2/3`。
- `player.gd` 直接轮询 `KEY_W/A/S/D/SHIFT/SPACE/R/1-5` 和鼠标左右键/滚轮。
- 没有任何 `InputMap` 动作，没有 `JOY_BUTTON_*`，没有手柄轴。
- 结论：当前版本在键盘+鼠标之外**不可操作**；“支持手柄”在阶段五验收中目前是不成立的。

### 5.4 动效

| 动效 | 实现 | 时长/行为 |
|---|---|---|
| 击杀信息 | `Tween` | 0.14s 淡入，停留 3.2s，0.5s 淡出，节点释放 |
| 波次横幅 | `Tween` | 0.16s 淡入，`duration` 停留，0.45s 淡出；新横幅会 kill 旧 Tween |
| 加载文案 | `_process` | `sin` 呼吸透明度 |
| 受伤暗角 | `_process` + `_draw` | 每帧 9 层红边，低血量脉冲 |
| 准星命中 | `_process` + `_draw` | 0.22s 命中标记 |
| 菜单背景 | `_process` + `_draw` | 每帧 46 粒子 + 全屏重绘 |
| 小地图 | 每次数据更新 + `_draw` | 每次重绘整张地图 |
| 覆盖层显示/隐藏 | `visible` 切换 | **瞬时，无过渡** |
| 按钮 hover/press | Theme 样式切换 | 只有颜色/边框变化，无位移/缩放/过渡 |

没有“减少动效/关闭非必要动画”选项；暗角在低血量时持续脉冲。

### 5.5 固定尺寸与适配风险

- 基准 1280×720，`canvas_items + expand`；UI 逻辑尺寸随宽高比扩展，但内部仍是固定像素面板。
- 菜单外层 `MarginContainer` 的最小高度为 **741px**（HARNESS_VERIFIED），大于 720；在 16:9 和 21:9 下底部被裁切，在 16:10（1920×1200 逻辑 1280×800）下才放下。
- HUD 左列固定 278×342，加右上 216×262、右下 268×192；在 1280×720 下占据大量战斗视野。
- 没有安全区、DPI 缩放、HUD 缩放或超宽专项布局。
- 军械库 7 张卡片在 1280 下刚好排满；再多一把武器或更长的中文名就会溢出，且没有滚动。

## 6. 运行时证据

### 6.1 真实游戏窗口（RUNTIME_VERIFIED）

截图索引、条件、实际尺寸见 [shots/README.md](shots/README.md)。关键观察：

- 主菜单 1280×720：右侧简报底部最后一行被裁切；退出按钮仍可见。
- 战斗 1280×720：左列 3 个面板占 296px 高，右上小地图 262px 高；底部提示在暗路面上可读，在明亮地面几乎不可读。
- 搬运核心：弹药面板仍显示 `36 / 144`、绿色“就绪”，但实际无法射击/换弹；只有任务面板和横幅说明搬运限制。
- 地下弹药补给：世界内 `弹药补给 [E]` 占据中央，HUD 同时显示 `E 补充弹药`；底部提示在浅色地面上对比度极低。
- 大厅：房主 1 人时 3 个空槽 + “全员已准备”同时出现。
- 任务结束：自动流程返回主菜单，档案更新；**没有捕捉到任务完成覆盖层**，该状态由离屏审计补充。
- 加载：0.15s 抓取时已进入战斗；**没有捕捉到加载覆盖层**，由离屏审计补充。

### 6.2 离屏分辨率审计（HARNESS_VERIFIED）

工具：[`tools/ui_audit.gd`](tools/ui_audit.gd)，49 次渲染，覆盖 12 个界面状态 × 1280×720 / 1920×1080 / 1920×1200 / 2560×1080，部分 HUD 状态增加明亮背景。

复现的布局事实：

| 事实 | 1280×720 | 1920×1080 | 1920×1200 | 2560×1080 |
|---|---|---|---|---|
| 菜单内容最小高度 | 741 | 741 | 741 | 741 |
| 菜单是否越界 | 是（21） | 是（21 逻辑 / 31.5 物理） | 否 | 是（21 逻辑 / 31.5 物理） |
| 4 人小队面板实际高 | 243 | 243 | 243 | 243 |
| 小队×任务重叠 | 71 逻辑 | 71 逻辑 | 71 逻辑 | 71 逻辑 |
| 生命面板越出底边 | 5 逻辑 | 5 逻辑 | 5 逻辑 | 5 逻辑 |
| 抽卡/军械库/背包 `FOCUS_NONE` 卡片 | 3 / 7 / 2 | 同左 | 同左 | 同左 |

审计局限：

- `Label.get_visible_line_count()` 在未设置 `clip_text` 时不会报告“被父容器/视口裁掉”，所以 JSON 的 `clipped_labels` 为 0 并不代表没有裁切；菜单和生命面板的裁切由根节点/面板越界与截图像素共同确认。
- 明亮背景是纯色 `#b9c6c9`，不是真实地下场景；它用于暴露对比度下限，不能替代真实场景采样。
- 注入的 4 人队伍、低血量、空弹药、任务状态是代表性数据，不代表真实网络局。

### 6.3 对比度测量

测量方法：设计色按 WCAG 相对亮度公式计算；底部提示用真实 1280×720 明亮截图在文本区域取中位背景色，并按代码中的 `Color(0.62,0.72,0.72,0.7)` 合成。

| 对象 | 实测/计算 | 要求 | 结论 |
|---|---:|---:|---|
| 底部常驻提示（明亮背景 + 低血量） | **1.12:1** | ≥4.5:1 | 失败 |
| 底部提示设计色上限（纯 `#b9c6c9`） | 1.39:1 | ≥4.5:1 | 失败 |
| 底部提示（暗背景） | 4.35:1 | ≥4.5:1 | 边缘失败 |
| 禁用按钮“使用中” | 3.01–3.11:1 | ≥4.5:1（18px 非大号） | 失败 |
| 抽卡描述（琥珀卡） | 4.00:1 | ≥4.5:1 | 失败 |
| 抽卡 `Lv`（琥珀卡） | 4.27:1 | ≥4.5:1 | 失败 |
| 抽卡标题（白 on 深青/深琥珀/深蓝） | 5.47–6.19:1 | ≥4.5:1 | 通过 |
| `MUTED` on 面板 | 6.76:1 | ≥4.5:1 | 通过 |
| 生命“危险”红 on 面板 | 6.25:1 | ≥4.5:1 | 通过 |

注意：以上是色值与截图采样，不等于“所有动态背景上都达标”；真实场景需要逐帧/多背景采样。

## 7. 问题清单（按优先级）

严重度：P0 = 阻断核心流程或验收；P1 = 明显影响理解/操作/可访问性；P2 = 质量与维护性问题。

| ID | 级别 | 问题 | 证据 | 影响 |
|---|---|---|---|---|
| UX-01 | P0 | 4 人小队面板撑高到 243，压住任务面板 71px，第 4 名队员不可见/透出 | JSON `panel_overlaps`、`hud_1280/1920` 截图 | 联机时看不到队友生命，直接损害合作战斗 |
| UX-02 | P1 | 生命面板实际 121 高，所有分辨率越出底边 5 逻辑 px | JSON `out_of_viewport` | 底部状态文字被裁，面板贴边不完整 |
| UX-03 | P0 | 主菜单最小高 741 > 720，右侧简报底部裁切，无滚动 | JSON 根节点、菜单截图 | 首屏信息缺失，玩家看不到完整规则/提示 |
| UX-04 | P0 | 无 `[input]`、无手柄映射；移动/射击/UI 全硬编码键鼠 | `project.godot`、`player.gd`、`main.gd` | 手柄/Steam Deck 不可玩；无法满足“支持手柄”验收 |
| UX-05 | P0 | 所有按钮焦点不可见；抽卡/军械库/背包卡片 `FOCUS_NONE` | Theme `focus=StyleBoxEmpty`、审计计数 | 键盘/手柄用户无法判断焦点，卡片无法导航 |
| UX-06 | P0 | 常驻 11px 底部提示在明亮地面 1.12:1 | 截图采样 | 战斗中读不到操作提示；视觉噪音 |
| UX-07 | P1 | 搬运核心时弹药面板仍显示“就绪”，无“无法射击”状态 | `mission_carry` 截图 | 玩家以为可以开火，输入被吞 |
| UX-08 | P1 | 世界 Label3D 与 HUD 重复提示同一交互，世界标签占中央 | `mission_ammo` 截图 | 信息源冲突，遮挡视野 |
| UX-09 | P1 | 8–11px 中文承担关键数值/说明；情报武器行出现单字换行 | 审计字号分布、`intel` 截图 | 可读性差，中文断行难看 |
| UX-10 | P1 | 加载进度条固定 64%，非真实进度且不可取消 | `show_loading` 代码、审计截图 | 误导等待预期 |
| UX-11 | P1 | 大厅空槽“等待队员加入”与“全员已准备”同时出现；客户端准备无 pending 态 | `lobby_host` 截图、`main_menu` 代码 | 状态自相矛盾，网络慢时反馈不清 |
| UX-12 | P1 | 抽卡/军械库/背包 10–13px 密集文案；禁用态低对比；背包大卡片大面积空白 | 截图 + 对比度 | 选择成本高，状态难辨 |
| UX-13 | P2 | 小地图红框/红 LIVE 与危险语义冲突；丧尸只靠颜色区分 | 截图 + `minimap.gd` | 误读威胁；色觉障碍用户不可用 |
| UX-14 | P1 | 联机暂停只释放输入，不冻结服务器；覆盖层不显示实时生命/队伍状态 | `main._pause_game` 代码 | 玩家在“暂停”界面仍可能被攻击，缺少反馈 |
| UX-15 | P1 | 无 HUD 缩放、高对比、减少动效选项 | 全工程搜索 | 无法满足 Xbox 无障碍指南/低视力玩家 |
| UX-16 | P2 | 准星在明亮地面依赖阴影，命中标记只靠颜色 | 截图 + `crosshair.gd` | 强光下瞄准反馈弱 |
| UX-17 | P2 | 常驻操作提示与一次性教学混在一起 | HUD 底部提示 | 老玩家持续被占用视野，新玩家缺少分步引导 |
| UX-18 | P1 | 世界标签字号 26–58、pixel_size 0.0032–0.004，多个标签可同时进入视野 | `mission_site.gd`、截图 | 中央视野遮挡，破坏低多边形场景主体 |
| ENG-01 | P1 | 所有 UI 代码构建；0 个 UI 场景/Theme 资源；163 处 `add_theme_*` | 资源清单/计数 | 无法做视觉迭代、复用、可视化回归 |
| ENG-02 | P1 | `main.gd` 2,514 行、HUD 1,509 行、菜单 809 行，业务/展示/文案混合 | 行数/结构 | 改动风险高，难以测试 |
| ENG-03 | P1 | `hud.call("...")` + `has_method` 动态调用，缺类型约束 | `main.gd:810/846/852/859/865` | 方法改名后静默失效 |
| ENG-04 | P1 | 固定像素矩形 + `PanelContainer` 最小尺寸撑开，缺安全区/内容驱动 | 审计 | 已导致 UX-01/02/03 |
| ENG-05 | P2 | UI 文案（任务提示、交互提示、错误）散落在 `main.gd` 与 HUD | 代码 | 难以统一语气/本地化 |
| PERF-01 | P2 | 主菜单隐藏后 `MenuBackdrop._process` 仍每帧更新 46 粒子并全屏重绘 | `menu_backdrop.gd:50`、`main.gd:610` | 游戏中持续无效开销（未 profiler 量化） |
| PERF-02 | P2 | 小地图每次更新重绘，`_draw()` 每次新建 `SystemFont`；HUD 每帧格式化任务/弹药字符串 | `minimap.gd`、`main.gd:747` | 潜在 CPU/分配开销（未 profiler 量化） |
| TEST-01 | P1 | 18 + 150 个逻辑测试全过，但 0 个 UI 布局/焦点/对比度测试 | 测试运行结果 | “测试通过”不能证明 UI 可用 |

## 8. 缺失与不可验证项

| 项 | 状态 | 说明 |
|---|---|---|
| 真实 4 人联机 HUD/大厅 | UNVERIFIED | 审计用注入数据复现了布局缺陷；未启动 3 个真实客户端 |
| 任务完成/失败覆盖层真实流程 | UNVERIFIED | 自动任务结束直接回主菜单；覆盖层仅离屏渲染 |
| 真实加载覆盖层 | UNVERIFIED | 0.15s 抓取已进入战斗 |
| 真实受击暗角/低血量 | PARTIAL | 离屏低血量渲染 + 明亮背景截图；未抓取真实受击瞬间 |
| 1920×1200 真实窗口 | UNVERIFIED | 桌面可用高度把窗口夹到 1920×1055；分辨率结论来自离屏审计 |
| 超宽真实窗口 | UNVERIFIED | 2560×1080 仅离屏审计 |
| 手柄/Steam Deck | UNVERIFIED | 代码层已确认无映射，未做硬件测试 |
| 联机暂停时是否仍会受伤 | UNVERIFIED | 代码允许服务器继续；未实战验证 |
| 性能数字 | UNVERIFIED | 未跑 profiler；PERF 仅为静态线索 |
| 3–5 名测试者可用性 | NOT DONE | 阶段五内容 |
| TLOU/Detroit 视频时间码 | NOT DONE | 只取得可核实静帧与发行方页面；未逐帧看录像，不编造时间码 |
| 本地 UI 动效演示工程 | NOT FOUND | 已搜索 `D:\游戏教学`、`D:\QoderWorkspace` 下的 Godot 工程；未发现包含 hover/press/show-hide/transition/数字变化演示的工程。AI_ 内只有横幅/击杀/加载/暗角/准星动效 |

## 9. 复现与校验命令

```bash
# 逻辑回归
godot --headless --path . --script res://tests/test_city_layout.gd
godot --headless --path . --script res://tests/test_mission.gd

# 菜单 1280 / 1920x1080 / 1920x1200 / 2560x1080
for wh in 1280x720 1920x1080 1920x1200 2560x1080; do
  w=${wh%x*}; h=${wh#*x}
  godot --path . --script res://ui_refactor/phase1/tools/ui_audit.gd -- \
    --screen=menu --w=$w --h=$h --out=D:/游戏教学/测试/AI_/ui_refactor/phase1/audit --bg=dark
done
```

真实窗口截图由 `main.gd` 的 CLI 入口生成：`--auto-solo`、`--auto-host`、`--capture=`、`--capture-after=`、`--auto-mission`、`--mission-shots=`、`--intel-shot=`、`--backpack-shot=`、`--armory-shot=` 等。命令与状态条件见 [shots/README.md](shots/README.md)。

## 10. 执行记录（本阶段）

- **CHANGED**：仅新增 `ui_refactor/phase1/`（报告、审计工具、审计输出、参考静帧、截图索引）。生产代码零修改。
- **IMPLEMENTATION**：没有实现阶段四 UI；只新增只读审计工具 `ui_audit.gd`，它实例化生产 `MainMenu`/`GameHUD` 并调用其公开方法注入状态。
- **TESTS**：`test_city_layout.gd` 18 checks / 0 failures；`test_mission.gd` 150 checks / 0 failures。无 UI 布局测试。
- **RUNTIME**：真实窗口 1280×720 截图 11 张 + 任务流程 9 张（共 20 张）；离屏审计 49 次。1920×1200 真实窗口被系统夹到 1920×1055。
- **GIT**：`c805ed5`；`git status` 仅 `M icon.svg.import`（预先存在）与 `?? ui_refactor/`。
- **UNVERIFIED**：见第 8 节。
