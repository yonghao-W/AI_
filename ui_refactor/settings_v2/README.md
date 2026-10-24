# 玩家设置中心 V2

- 代码基准：`1af055e`
- 入口：主菜单“设置”、游戏内暂停菜单“设置”
- 配置：`user://ui_settings.cfg`（版本 2，兼容旧文件）
- 视觉模板：`D:\BaiduNetdiskDownload\DeadCity_Player_Settings_Template`（仅作视觉/交互参考，未嵌入 HTML）

## 1. 真实实现的设置

| 分类 | 设置 | 真实作用点 |
|---|---|---|
| 操作与鼠标 | 水平/垂直灵敏度、开镜倍率、反转 Y、FOV、ADS FOV、瞄准按住/切换 | `player.gd` 鼠标相对位移、Camera3D FOV、aiming 状态 |
| 画面与镜头 | 窗口化/无边框/独占全屏、分辨率、VSync、帧率上限、3D 渲染比例 | `DisplayServer`、`Engine.max_fps`、根 Viewport `scaling_3d_scale` |
| 声音 | 总音量、战斗音效、界面反馈 | Master / SFX / UI Audio Bus；武器与感染者→SFX，界面提示→UI |
| 界面与准星 | HUD 缩放/背景浓度、准星大小/颜色/粗细、命中反馈、小地图、任务目标 | `game_hud.gd`、`crosshair.gd`、HUD 遮罩与面板 |
| 按键绑定 | 移动、跳跃、冲刺、射击、瞄准、换弹、交互、放下核心、武器切换、情报、背包、暂停 | `InputMap` + `player.gd` / `main.gd` |
| 辅助功能 | 高对比度、减少动效、受伤闪烁强度、交互提示 | HUD/菜单主题、浮尘/视差/过渡、`DamageVignette` |

当前工程**没有**音乐、独立环境音、语音、蹲伏、镜头晃动控制器、字幕系统，或可安全运行时切换的阴影/抗锯齿/后处理路径，因此没有为这些项目提供假滑块。设置页会明确说明。

HUD 背景浓度只调整 HUD 渐变遮罩的 alpha，不改变文字亮度。

## 2. 数据架构

- `scripts/settings_schema.gd`：唯一设置定义源，包含 ID、类型、默认值、范围/候选项、分类、说明。
- `scripts/ui_settings.gd`：autoload 设置服务。
  - `_applied`：上次应用并保存的值。
  - `_pending`：当前 UI 编辑值；可即时预览。
  - `apply()`：pending → applied，写配置并应用。
  - `cancel()`：pending → applied，撤销未应用修改。
  - `reset_category()` / `reset_all()`：只改 pending，需应用才保存。
  - `find_key_conflict()` / `set_pending_key()`：键位冲突检测与即时 InputMap 更新。
- 保存结构：
  - `[meta] version=2`
  - `[controls]`、`[display]`、`[audio]`、`[ui]`、`[accessibility]`、`[input]`
- 旧配置迁移：读取旧 `[audio] master_volume`、`[display] fullscreen/vsync`、`[ui] hud_scale`、`[accessibility]`，缺失或非法值回退默认；损坏文件安全回退。
- 所有设置只影响本机，不修改网络协议、服务器权威数值、存档或任务状态。

## 3. 交互

- 左侧六分类导航；中部 `ScrollContainer` 选项；右侧当前项说明与 FOV/准星示意；底部应用/取消/恢复本页默认。
- 滑块即时预览（灵敏度、FOV、音量、HUD、准星）；取消恢复上次应用值。
- 显示模式/分辨率等显示设置：应用时弹出 10 秒确认；未确认自动恢复原设置。
- 按键捕获：点击按键行后按键盘/鼠标；Esc 取消；冲突按键拒绝并提示；保留 Esc/`ui_cancel` 安全返回路径。
- 主菜单与暂停菜单打开同一实例；联机暂停中打开设置不会暂停服务器模拟。
- 减少动效时关闭非必要过渡；不延迟输入。

## 4. 截图

`ui_refactor/settings_v2/shots/`（共 26 张真实 Godot 渲染：24 张分类 + 暂停入口 + 显示确认）：

- `settings_controls_1280x720.png` 等 6 分类 × 4 分辨率
- `settings_from_pause_1280x720.png`
- `settings_display_confirm_1280x720.png`

截图目录按 `.gitignore` 忽略；可用 `ui_refactor/settings_v2/tools/capture_settings.gd` 重建。

## 5. 测试

- `tests/test_settings_v2.gd`：99 checks / 0 failures
- `tests/test_ui_integration.gd`：105 / 0
- `tests/test_ui_display.gd`：120 / 0，4 条 UI 放大压力 warning
- `tests/test_ui_network.gd`（4 人）：HOST 23 / 3×CLIENT 19，0 失败
- `tests/test_city_layout.gd` 18/0；`test_mission.gd` 150/0；`test_chapter_one.gd` 230/0；章节联机通过
- 真实显示探针：borderless 模式切换/恢复、1600×900、`scaling_3d_scale=0.75`、`Engine.max_fps=90` 均验证

## 6. 未验证

- 真实手柄硬件（未测试，不声明支持）
- 真实玩家可用性测试
- Windows OS 级 125%/150% 显示缩放
- 最低规格硬件、长时间运行、真实显示器异常回退
- 音乐/环境音/语音（工程没有对应资源）
- 阴影/抗锯齿/后处理（未接入安全运行时路径）
- 真实 WAN 网络下的设置页与联机行为

## 7. 回退

- 设置 V2 之前：`981c7e6`
- 设置 V2 实现：`1af055e`
- 旧 UI 对照：`git worktree add /d/tmp/deadcity_old_ui db0b452`
- 本任务未 push。
