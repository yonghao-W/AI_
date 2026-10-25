# I · HUD Art V3 视觉集成

- 参考包：`D:\BaiduNetdiskDownload\DeadCity_HUD_Art_V3_Editable.zip`
- 解压参考：`ui_refactor/hud_art_v3/DeadCity_HUD_Art_V3/`（本地参考，不随工程打包）
- 实际代码：`scripts/game_hud.gd`、`scripts/ui/hud_compass.gd`、`scripts/minimap.gd`
- 对照图：`ui_refactor/hud_v3_actual_vs_reference.png`

## 1. 接入原则

V3 包是视觉资产，不是可运行 UI。没有把整张 SVG/PNG 贴进游戏，而是按 `squad / mission / minimap / health / weapon_state / interaction` 分组用原生 Godot 控件重建；文字、血量、弹药、任务和网络数据继续来自现有 setter。

## 2. 实际布局

| V3 分组 | Godot 实现 |
|---|---|
| `squad` | 左上无边框名单：编号、姓名、生命线、状态点；1 人时隐藏 |
| `mission` | 右上：菱形图标、回收核心、进度、章节/提示；与圆形小地图并排 |
| `minimap` | 右上 144px 圆形地图，圆形 shader 遮罩 + 边框；道路/街区线条，玩家三角 |
| `health` | 左下无底板：加号图标、34px 生命数字、`/100`、190px 细条、生命标签 |
| `weapon_state` | 右下无底板：武器名/射击模式、发丝线、36px 弹匣/备弹、弹匣图标、弹匣/备弹说明 |
| `interaction` | 屏幕中下方，保留现有交互提示与按键文字 |
| `carry_event` | 搬运时隐藏弹药组，右下显示“正在搬运核心 / 无法射击·无法换弹 / G 放下核心” |
| 顶部罗盘 | 新增 `HUDCompass`：真实玩家 yaw 驱动，刻度 + N/E/S/W + 度数 + 琥珀中心标记 |

边缘只保留 V3 式**弱防背光渐变**（左/右/底/顶），不是整块卡片或全屏黑遮罩；HUD 缩放/背景浓度/高对比/减少动效仍由设置系统控制。

## 3. 未直接照搬的部分

- 没有使用 V3 的 AI 合成背景，实际背景是 E-07 场景。
- 没有把整张 `HUD_normal.svg` 作为贴图；所有数值/文字/焦点仍是实时控件。
- V3 SVG 未包含独立罗盘分组，罗盘按预览效果用原生 `_draw` 实现。
- 小地图是现有程序化街区的圆形化重绘，不是 V3 的插画街道底图。
- V3 的 `HUD_combat` 红弧/剩余感染者提示目前仍由现有波次/横幅系统承担，没有新增独立动画层。
- 搬运“核心已获取”中心提示沿用现有 announce，不新增剧情。

## 4. 验证

| 项目 | 结果 |
|---|---|
| 设置 V2 | 106 / 0 |
| UI 集成 | 105 / 0 |
| 显示矩阵 | 120 / 0，8 条 UI 放大压力 warning |
| 4 人联机 UI | HOST 23 / 3×CLIENT 19，0 |
| 视觉矩阵 | 52 张 / 0 差异 |
| 对比度 | 250 元素，5 项低于 4.5:1 |
| 第一章逻辑 | 230 / 0 |

截图（实际 Godot 渲染）：

- `shots/hud_v3.png` 正常战斗 HUD
- `shots/hud_v3_squad.png` 四人小队
- `shots/hud_v3_carry.png` 搬运状态
- `ui_refactor/hud_v3_actual_vs_reference.png` 参考 vs 实际（normal/carry）
- `ui_refactor/hud_occlusion_before_after.png` 遮挡修复前后

## 5. 回退

- V3 之前 HUD：`c9dd111`
- V3 视觉集成：本提交
- V3 参考包不进入发行包；只保留 `assets/ui/hud/icons/` 中实际使用的 5 个图标。
