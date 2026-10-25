# H · HUD 黑色遮挡修复报告

- 代码基准：`0b15fbe` 之后的本轮修复
- 场景：E-07 三楼观察室出生点，1280×720
- 对照图：`ui_refactor/hud_occlusion_before_after.png`

## 1. 现象与根因

用户看到的三处异常：

| 现象 | 根因 |
|---|---|
| 左上角大块黑色区域 | `GameHUD` 的全屏 `_scrim_top`（1280×250） |
| 左下角边界整齐的黑色矩形 | `GameHUD` 的 `_scrim_left`（560×330，左下锚点） |
| 左侧倾斜的黑色多边形 | `GameHUD` 的 `_scrim_corner`（430×370，对角渐变） |

这些不是 3D 几何、CSG 或阴影，而是 UI 遮罩：它们覆盖大面积游戏视野，暗色渐变在暗场景里看起来像黑色遮挡。之前修过渐变端点索引（白带），但仍保留了全屏遮罩，导致新的黑色区域。

**层隔离验证**

- HUD 显示：黑块出现。
- `hud.visible = false`：黑块全部消失，露出正常房间。
- 仅隐藏四个 scrim、保留 HUD：黑块消失。
- 结论：异常由 HUD 遮罩造成，不是相机/网格/灯光。

## 2. 修改内容

**`scripts/game_hud.gd`**

- 删除 `_scrim_top`、`_scrim_left`、`_scrim_right`、`_scrim_corner` 及两个渐变纹理生成函数。
- 新增三个紧凑的圆角局部 `PanelContainer` 背景：
  - 任务：`Rect2(16,12,320,112)`
  - 生命：`Rect2(18,-90,264,78)`
  - 弹药：`Rect2(-300,-96,280,84)`
- “任务目标”关闭时，任务背景同步隐藏。
- `hud_opacity` 只作用于这三个局部背景，不再覆盖全屏。
- 弹药组重排：武器名/射击模式置顶，弹匣/备弹与状态分层，避免大块空白。
- 保留 HUD 内容、小地图、准星、武器条、设置联动。

**`scripts/player.gd`**

- 相机下新增 `ViewmodelFill` 补光（`OmniLight3D`，range 2.4，无阴影），解决枪械全黑。
- 手电 `SpotLight3D`：`spot_angle_attenuation = 2.2`，能量 1.7 → 1.35，软化锥形边缘。

**`scripts/chapter_one_station.gd`**（前一轮延续）

- 按网格名前缀分配混凝土/外墙/内墙/金属/木材质。
- 增加室内填充光、观察灯和天花板补光，避免背光墙柱死黑。

**`scripts/settings_schema.gd` / `tests/test_settings_v2.gd`**

- HUD 背景浓度说明改为“局部信息背景”。
- 测试改为检查 `_hud_backdrops`，仍覆盖 0.6 透明度。

## 3. 验证

| 项目 | 结果 |
|---|---|
| 设置 V2 | 106 / 0 |
| UI 集成 | 105 / 0 |
| 显示矩阵 | 120 / 0，4 warning |
| 视觉矩阵 | 52 张 / 0 差异 |
| 渲染像素对比度 | 246 元素，5 项低于 4.5:1 |
| 第一章逻辑 | 230 / 0 |

截图：

- `shots/occlusion_before.png`：修复前，全屏遮罩黑区。
- `shots/occlusion_hud_off.png`：隐藏 HUD，黑区消失。
- `shots/occlusion_after.png`：修复后，局部任务/生命/弹药背景。
- `ui_refactor/hud_occlusion_before_after.png`：三联对照。

## 4. 说明

- 修复后左上仍可能有**3D 天花/上墙的暗部**，它不再有整齐矩形/对角边界；已加天花板补光。若仍觉得过暗，可继续调室内曝光或材质，而不是 HUD。
- 没有修改网络协议、存档、任务状态机、武器数值、小地图逻辑或设置系统。
- 回退：恢复 `game_hud.gd` 的 scrim 实现与 `player.gd` 灯光即可；本轮提交在完成后记录。
