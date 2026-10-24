# 《死城突围》UI/UX 重构 · 阶段一证据与诊断

本目录只包含**阶段一**成果：工程事实、原始运行证据、参考游戏证据、问题诊断与有优先级的试点方案。没有修改任何生产 UI、玩法、网络、存档或任务代码。

## 固定版本

| 项目 | 值 |
|---|---|
| 仓库 | https://github.com/yonghao-W/AI_ |
| 分支 | `main` |
| 提交 | `c805ed5ff04ab56381cd36fe5b2e803164750cba`（短 `c805ed5`） |
| Godot | 4.7.2 stable official `ed1daf0bf` |
| 渲染 | Forward+ / Vulkan |
| 基准视口 | 1280×720，`canvas_items` + `expand` |
| 本阶段工作区变更 | 仅新增 `ui_refactor/`；`icon.svg.import` 为进入本阶段前已存在的修改 |

## 文件地图

| 文件 | 作用 |
|---|---|
| [A_工程证据与架构审计.md](A_工程证据与架构审计.md) | 入口、节点组织、信号、数据源、样式/动效/输入/适配/耦合、运行时证据、问题清单 |
| [B_参考证据库.md](B_参考证据库.md) | 《最后生还者 第二部》《底特律：变人》可核实静帧与发行方无障碍资料，逐案记录可借鉴/不可借鉴 |
| [C_诊断与试点方案.md](C_诊断与试点方案.md) | 保留/重做/仅样式/工程拆分/证据不足的分类，以及分阶段试点与验收 |
| [audit/README.md](audit/README.md) | 离屏分辨率审计工具、运行命令、方法边界 |
| [audit/summary.json](audit/summary.json) | 49 次离屏渲染的机器可读汇总 |
| [shots/README.md](shots/README.md) | 真实游戏窗口截图索引、实际尺寸、缺失状态 |
| [refs/](refs/) | 参考游戏静帧，仅用于分析，不作为本项目美术资产 |

## 证据等级

本阶段统一使用以下标签，避免把“脚本能解析”说成“界面已验证”：

- **RUNTIME_VERIFIED**：真实游戏窗口运行并截图，或真实测试脚本运行通过。
- **HARNESS_VERIFIED**：把生产 `MainMenu` / `GameHUD` 节点放入离屏 `SubViewport`，注入代表性状态后渲染、测量。节点与绘制路径是生产代码，但网络、玩家输入和场景内容不是真实流程。
- **STATIC_VERIFIED**：只由代码、配置、资源清单得出的结论。
- **UNVERIFIED / NOT FOUND**：没有取得足够证据，或明确搜索后不存在。

## 一分钟结论

1. 现有 UI 不是“风格不够高级”，而是**信息布局没有内容驱动的尺寸与安全区**：4 人小队面板实际高度 243px（目标 164px），在所有目标分辨率都压住任务面板 71px；生命面板实际 121px（目标 96px），在所有目标分辨率都越出底边 5px。
2. 主菜单在 16:9 下最小高度 741px > 720px，右侧行动简报底部被裁切且没有滚动容器；1920×1200 能放下，说明这是**纵向预算**问题，不是字体大小问题。
3. 键盘/手柄路径实际上不可用：`project.godot` 没有 `[input]`，没有手柄动作；主题的 `focus` 是 `StyleBoxEmpty`，抽卡/军械库/背包卡片被显式设为 `FOCUS_NONE`。
4. 常驻底部操作提示在明亮地面上实测对比度约 **1.12:1**（设计值上限也只有 1.39:1），11px 常驻文本在真实战斗场景中不可读。
5. 视觉身份（深青绿、琥珀、低多边形夜景）可以保留；需要重做的是**布局系统、状态表达、焦点与输入、覆盖层层级**，不是换一张更“AAA”的皮。

## 复现

```bash
# 逻辑回归（已有测试）
godot --headless --path . --script res://tests/test_city_layout.gd   # 18 checks
godot --headless --path . --script res://tests/test_mission.gd       # 150 checks

# 生产 UI 的离屏分辨率审计（示例）
godot --path . --script res://ui_refactor/phase1/tools/ui_audit.gd -- \
  --screen=hud --w=1920 --h=1200 \
  --out=D:/游戏教学/测试/AI_/ui_refactor/phase1/audit --bg=dark
```

`ui_audit.gd` 按工程的 `canvas_items + expand` 规则计算缩放：物理像素 = 逻辑像素 × `min(w/1280, h/720)`，另一轴作为额外逻辑空间。例如 1920×1200 的逻辑画布是 1280×800，而不是把 1280×720 拉伸。

## 阶段边界

- 本阶段**没有**开始阶段四的实现，没有改生产 `.gd`、`.tscn`、`.tres`、`project.godot`。
- 回退方式：删除 `ui_refactor/` 即可；生产代码零改动。
- 下一道闸门：阶段一诊断被确认后，才进入阶段二体验模型与阶段四试点。D（试点实现）、E（验证报告）尚未开始。
