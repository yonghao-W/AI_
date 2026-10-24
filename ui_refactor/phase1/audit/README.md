# audit · 离屏分辨率审计工具与结果

本目录不是截图画廊，而是**对生产 UI 节点做离屏渲染和几何测量的可复现实验记录**。工具只调用 `MainMenu` / `GameHUD` 已有的公开或下划线方法注入状态，不修改、不 fork、不复制生产 UI 逻辑。

- 工具：[`../tools/ui_audit.gd`](../tools/ui_audit.gd)
- 汇总：[`summary.json`](summary.json)（49 条，缺字段时以单次 JSON 为准）
- 单次结果：`<screen>_<w>x<h>_<bg>.png` + 同名 `.json`

证据等级为 **HARNESS_VERIFIED**：节点与绘制路径是生产代码，但输入、网络和 3D 场景不是真实流程。

## 1. 为什么要离屏渲染

1920×1200 的真实游戏窗口在这台机器上被 Windows 可用高度夹到 1920×1055，无法直接得到 1200 高的证据。离屏 `SubViewport` 可以：

1. 在任意物理尺寸下重复渲染同一份生产 UI；
2. 同时输出像素图和精确的 `Rect2`、最小尺寸、字号、焦点样式；
3. 把“布局越界/面板重叠”从肉眼判断变成可复算的数字；
4. 在明亮、深色两种背景下检查同一布局，避免只在深色背景上“看起来没问题”。

它**不能**替代真实窗口：输入事件、网络状态、3D 遮挡、字体栅格化和真实场景对比度仍需真实运行或单独采样。

## 2. 缩放规则

工具按 `project.godot` 的 `canvas_items` + `expand` 计算：

```text
ui_scale   = min(w / 1280, h / 720)
logical    = (w / ui_scale, h / ui_scale)
physical   = logical × ui_scale
```

多出来的轴是**额外逻辑空间**，不是非均匀拉伸。因此右/下锚定的面板会随逻辑画布移动，而不是保持 1280×720 的比例。

| 物理尺寸 | ui_scale | 逻辑画布 | 说明 |
|---|---:|---|---|
| 1280×720 | 1.0 | 1280×720 | 基准 |
| 1920×1080 | 1.5 | 1280×720 | 16:9，整体放大 |
| 1920×1200 | 1.5 | 1280×800 | 16:10，多 80 逻辑像素高度 |
| 2560×1080 | 1.5 | 1706.67×720 | 21:9，多 426.67 逻辑像素宽度 |

## 3. 覆盖矩阵

49 次渲染来自 12 个界面状态在 4 个尺寸上的组合（**非满矩阵**：部分状态未跑满，部分 HUD 状态增加明亮背景）。`●` = 深色背景，`○` = 明亮背景，`—` = 未跑。

| 界面状态 | 1280×720 | 1920×1080 | 1920×1200 | 2560×1080 | 次数 |
|---|---|---|---|---|---|
| `menu` 主菜单 | ● | ● | ● | ● | 4 |
| `lobby` 主机大厅 | ● | ● | ● | ● | 4 |
| `armory` 军械库 | ● | ● | ● | — | 3 |
| `hud` 战斗 HUD | ●○ | ●○ | ●○ | ●○ | 8 |
| `pause` 暂停 | ● | ●○ | ● | ● | 5 |
| `intel` 战术情报 | ● | ●○ | ● | ● | 5 |
| `backpack` 背包 | ● | ●○ | ● | ● | 5 |
| `draw` 核心抽卡 | ● | ● | ● | ● | 4 |
| `gameover_victory` 胜利结算 | ● | ● | ● | ● | 4 |
| `gameover_fail` 失败结算 | ● | ● | — | — | 2 |
| `death` 倒地 | ● | ● | — | — | 2 |
| `loading` 加载 | ● | ● | ● | — | 3 |

> 明亮背景只用于检查浅色场景上的可读性；它不是游戏内真实光照，真实对比度另见 `A_工程证据与架构审计.md` 的截图采样。

## 4. 注入的代表性状态

所有状态通过生产节点的 setter/展示方法注入，数值为**合成的代表性数据**，不是实际网络负载。

| 状态 | 注入内容 | 目的 |
|---|---|---|
| `menu` | 12 次行动、7 次完成、战力 18、信用点 315、`total_cores=9`（Lv.3）、装备 `smg + machete` | 检查菜单纵向预算与档案区 |
| `lobby` | 4 人名单，3 人已准备、1 人未准备，`all_ready=false` | 检查 4 行名单、空槽、开始按钮禁用 |
| `armory` | 已拥有 4 把武器，7 张武器卡全部渲染 | 检查 7 列卡片与覆盖层 |
| `hud` | 4 人小队（1 人倒地）、第 4 波、生命 18/100、弹药 0/0、任务 2/3、交互提示 | 同时触发低血量、空仓、4 人名单、任务文本 |
| `pause` | 单人暂停 + “战斗仍在服务器上继续” | 检查暂停层与 HUD 共存 |
| `intel` | 三栏情报、武器数值行、强化 5 项 | 检查 10–11px 文本与换行 |
| `backpack` | 2 把出战武器、当前使用中 | 检查大卡片空白与禁用态 |
| `draw` | 3 张卡（扩容弹匣/快速装填/枪机抛光） | 检查 3 选 1、焦点与对比度 |
| `gameover_*` | 胜利/失败两套统计与档案行 | 检查结算层 |
| `death` | 倒地 6 秒倒计时 | 检查倒地覆盖层与 HUD |
| `loading` | “正在生成街区 #4242…” | 检查固定 64% 进度与脉冲文案 |

## 5. JSON 字段

| 字段 | 含义 | 判读注意 |
|---|---|---|
| `controls` | 所有可见 Control 的路径、类型、全局矩形、最小尺寸 | 全量明细，文件较大 |
| `out_of_viewport` | 任一边超出物理视口的 Control | 右/下锚定面板在窄高比下最容易出现 |
| `clipped_labels` | `Label.get_visible_line_count() < get_line_count()` | **会漏报**：未设 `clip_text` 时，被父容器裁掉不算 |
| `content_overflows` | `PanelContainer.size` 小于其最小尺寸 | 只检查 PanelContainer 自身 |
| `invisible_focus_buttons` | `focus` 样式为 `null` / `StyleBoxEmpty` 的按钮 | 包含 `focus_mode = NONE` 的按钮，因此它不等于“可获得焦点但看不见” |
| `focus_none_buttons` | 显式 `focus_mode = FOCUS_NONE` 的按钮 | 键盘/手柄无法到达 |
| `font_sizes` | 各字号的 Label 数量 | 用于统计 8–11px 文本占比 |
| `panel_content_overflow` | 子控件超出最近的 PanelContainer | 面板随内容一起长高时不会触发 |
| `panel_overlaps` | 屏幕根节点下**直接子级** PanelContainer 的两两相交 | 原文件字段为 `overlap_px`；`summary.json` 归一化为 `px` |
| `top_panels` | 顶层面板路径与矩形 | 复算重叠、锚点行为 |
| `ui_scale` / `logical_size` | 本次模拟的缩放与逻辑画布 | 与第 2 节公式一致 |

## 6. 运行

Godot 可执行文件（本机）：

```text
D:/BaiduNetdiskDownload/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe
```

单次（战斗 HUD，1920×1200，明亮背景）：

```bash
"D:/BaiduNetdiskDownload/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe" \
  --path "D:/游戏教学/测试/AI_" \
  --script res://ui_refactor/phase1/tools/ui_audit.gd -- \
  --screen=hud --w=1920 --h=1200 \
  --out="D:/游戏教学/测试/AI_/ui_refactor/phase1/audit" --bg=bright
```

复跑一个状态的四个尺寸：

```bash
for wh in 1280x720 1920x1080 1920x1200 2560x1080; do
  w=${wh%x*}; h=${wh#*x}
  "D:/BaiduNetdiskDownload/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe" \
    --path "D:/游戏教学/测试/AI_" \
    --script res://ui_refactor/phase1/tools/ui_audit.gd -- \
    --screen=menu --w=$w --h=$h \
    --out="D:/游戏教学/测试/AI_/ui_refactor/phase1/audit" --bg=dark
done
```

可用 `--screen=`：`menu`、`lobby`、`armory`、`hud`、`pause`、`intel`、`backpack`、`draw`、`gameover_victory`、`gameover_fail`、`death`、`loading`。

## 7. 已确认的关键测量

| 测量 | 数值 | 证据 |
|---|---|---|
| 主菜单/大厅根节点最小高度 | **741** 逻辑 px | 1280/1080/2560 下越界 21；1200 下不越界 |
| 4 人小队面板实际高度 | **243**（目标 164） | `hud_*` JSON `top_panels` |
| 小队面板压住任务面板 | **71** 逻辑 px；19,738 px²（1×）/ 44,410.5 px²（1.5×） | `panel_overlaps` |
| 生命面板实际高度 | **121**（目标 96） | 所有尺寸越出底边 5 逻辑 px |
| 不可达按钮 | 军械库 7、抽卡 3、背包 2 | `focus_none_buttons` |
| 焦点样式为空/不可见 | 军械库 13（其中 7 个 `FOCUS_NONE`）、大厅 7、菜单 5、抽卡 4（3）、背包 3（2）、暂停 2 | `invisible_focus_buttons` |
| 最小字号 | **8px**；10–11px 大量承担数值/说明 | `font_sizes` |

## 8. 方法边界（必须一起读）

1. **没有模拟输入事件**。焦点数量来自主题与 `focus_mode` 静态检查，不等于键盘/手柄实际可达顺序正确；焦点遍历未验证。
2. **没有真实 3D 场景**。背景是纯色 `#18222c` / `#b9c6c9`，不能证明准星、世界 Label3D、伤害暗角在真实光照下的可读性。
3. **不测动效**。截图在状态稳定后采集，Tween 的时长、缓动、打断、重复输入未验证。
4. **`clipped_labels` 为 0 是假阴性**。菜单与生命面板的裁切由根/面板越界和真实截图像素共同确认。
5. **重叠检测只覆盖屏幕根的直接子级 PanelContainer**。覆盖层内部、非 PanelContainer 的遮挡不会进入 `panel_overlaps`。
6. **`panel_content_overflow` 为 0 不代表没有溢出**。小队面板随内容长高，子 Label 仍“在面板内”，问题表现为面板压住别的面板。
7. **字体依赖系统**。工具与游戏都用 `SystemFont`（Microsoft YaHei UI / Noto Sans CJK SC），换机器可能改变文本宽度与换行位置。
8. **状态是合成的**。它验证的是“给定这组数值时的布局”，不是网络同步、存档或真实玩家行为。
9. **1920×1200 仅是离屏证据**。真实窗口被系统夹到 1055 高，见 [`../shots/README.md`](../shots/README.md)。

## 9. 复现性

- 工具不含随机数、时间戳或网络请求；同一 Godot 版本、同一字体、同一尺寸下应得到相同的几何结果。
- 单次 JSON 的 `render` 字段固定为 `SubViewport offscreen; production UI nodes, injected state`。
- `summary.json` 是 49 条单次结果的人工汇总；若两者冲突，以单次 JSON 和 PNG 为准。
