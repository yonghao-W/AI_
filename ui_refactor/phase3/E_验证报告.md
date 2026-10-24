# E · UI v3 验证报告

- 代码基准：`edd19c1`（UI v3 集成 + 可读性/小地图修复）
- 引擎：Godot 4.7.2 stable `ed1daf0bf`，Forward+
- 硬件：NVIDIA RTX 4060 Laptop，Windows 10.0.26200
- 默认窗口：1280×720；分辨率取证另用离屏 SubViewport
- 结论：**功能与主要回归通过；性能预算、真实玩家、真实手柄与 OS 级 DPI 仍未完成验证。**

## 1. 测试总表

| 测试 | 脚本 | 结果 | 备注 |
|---|---|---|---|
| 资产加载/结构 | `tests/test_abandoned_house_asset.gd` | 7 / 0 | 725 网格、114,350 顶点 |
| UI 集成 | `tests/test_ui_integration.gd` | 105 / 0 | 菜单、设置、HUD 真实状态、覆盖层、暂停、清理 |
| 输入/显示矩阵 | `tests/test_ui_display.gd` | 120 / 0，4 warning | dpi125/dpi150 通过；zoom125/150 为压力提示 |
| 联机 UI（4 人） | `tests/test_ui_network.gd` | HOST 23 / 3×CLIENT 19，0 失败 | 真实四进程 |
| 故障网络（2 人，300s） | `tests/test_ui_network.gd` + UDP 代理 | HOST 175 / CLIENT 172，0 失败 | 150ms RTT、2% 丢包、30ms 抖动 |
| 任务逻辑 | `tests/test_mission.gd` | 150 / 0 | |
| 第一章 | `tests/test_chapter_one.gd` | 230 / 0 | |
| 城市布局 | `tests/test_city_layout.gd` | 18 / 0 | |
| 章节联机 | `tests/test_chapter_network.gd` | 双端通过，2 人 | station_spawn=true |
| 视觉矩阵 | `tools/capture_ui_matrix.gd` + `visual_diff.py` | 52 / 52，0 差异 | 13 状态 × 4 分辨率 |
| 渲染像素对比度 | `tools/contrast_audit.gd` + `contrast_report.py` | 243 元素，5 项低于阈值 | 见第 5 节 |

## 2. 视觉回归

**方法**

- 状态：`menu`、`menu_coop`、`menu_settings`、`menu_armory`、`lobby`、`hud_normal`、`hud_low_health`、`hud_carry`、`hud_squad_four`、`pause`、`draw`、`backpack`、`intel`。
- 分辨率：1280×720、1920×1080、1920×1200、2560×1080。
- 稳定化：关闭减少动效以外的随机源；隐藏 3D 世界；暂停 SceneTree；隐藏瞬时波次横幅；固定 seed 4242；HUD 缩放 100%。
- 比较：SHA-256 + 逐像素差异比例，阈值 0.1%。

**结果**

- 52 张基线 / 52 张复跑，**0 失败**。
- 基线图：`ui_refactor/phase3/baselines/`（按 `.gitignore` 不入库）。
- 哈希与命令：`evidence/baseline_manifest.json`、`evidence/current_manifest.json`。
- 差异报告：`evidence/visual_diff.json`。

**复现**

```bash
Godot --path . --resolution 640x360 \
  --script res://ui_refactor/phase3/tools/capture_ui_matrix.gd -- \
  --out=ui_refactor/phase3/baselines \
  --manifest=ui_refactor/phase3/evidence/baseline_manifest.json \
  --commit=$(git rev-parse --short HEAD)

python ui_refactor/phase3/tools/visual_diff.py \
  --baseline ui_refactor/phase3/baselines \
  --current ui_refactor/phase3/shots/matrix_current \
  --out ui_refactor/phase3/evidence/visual_diff.json
```

## 3. 输入与显示

| 场景 | 结果 |
|---|---|
| 1280×720 基准 | 菜单 6 项、HUD 面板、焦点均通过 |
| DPI 等效 125%（1600×900，逻辑 1280×720） | 通过 |
| DPI 等效 150%（1920×1080，逻辑 1280×720） | 通过 |
| UI 放大 125%（1280×720，逻辑 1024×576） | 1 条菜单项越界 warning |
| UI 放大 150%（1280×720，逻辑 853×480） | 3 条菜单项越界 warning |
| 覆盖层开/关 10 次 | 输入锁定/恢复、准星恢复全部通过 |

- 本轮修复：小地图按实际 188px 尺寸重新定位，消除 1280 宽下右缘 2px 越界。
- 限制：dpi125/150 是“放大物理窗口 + 固定逻辑视口”的等效检查，不是修改 Windows 显示缩放后的真实 OS DPI 测试；zoom125/150 是 UI 放大压力，不是任务要求的 1280×720 最小分辨率。手柄未测试，不声明支持。

## 4. 联机与故障网络

**常规联机**

- 4 人：HOST 19 / 3 个 CLIENT 各 16 检查，0 失败。
- 覆盖大厅四人槽位、准备/取消、房主开始、HUD 4 行、联机暂停不暂停 SceneTree、恢复输入、返回清理。

**故障网络**

- 拓扑：`client → UDP 代理(17891) → host(17890)`。
- 注入：单程 75ms ± 30ms（RTT≈150ms）、2% 丢包。
- 时长：300 秒；2 人。
- 结果：HOST 175 / CLIENT 172 检查，0 失败；玩家数稳定 2，HUD 小队持续可见。
- 代理统计：up 4184 / down 9997 / dropped 315 / 1 client。
- 原始日志：`evidence/network/adverse_host.txt`、`adverse_client.txt`、`adverse_proxy.txt`。
- 已知噪声：长测结束断连时双端日志出现 `Node not found: "Main"` / invalid packet，属于退出竞态；两端退出码均为 0，未计入断言。若后续要消除，可在 teardown 前增加握手等待。

## 5. 渲染像素对比度

**方法**

- 采集 11 个真实状态：菜单、联机、整备、大厅、HUD 正常/低血/四人、暂停、强化、背包、情报。
- 对每个可见 Label/Button 记录实际字号、字色、矩形与 modulate。
- 将文字颜色 alpha 设为 0（保留布局）后重新渲染，抓取文字背后的真实背景像素。
- 按 WCAG 计算每个像素的最差对比度，取 p05；正文阈值 4.5:1，≥24px 阈值 3:1。
- 只审计当前最上层界面，排除被覆盖层遮住的 HUD/菜单元素；跳过完全透明文字。

**结果**

- 243 个有效元素，**5 项低于阈值**：
  - 低血波次横幅 22px/11px（2 项，p05 1.89/2.03）
  - 低血/四人状态“危险”9px（2 项，p05 3.02/2.68）
  - 菜单禁用副标题“当前版本不保存行动进度”（1 项，p05 3.44）
- 已做的修复：顶部/底部/左上渐变遮罩、半透明小队面板、默认 1px 描边与更强阴影、禁用项透明度 0.72、弹药分隔符提亮；2026-10-25 修掉 HUD 渐变端点索引错误（此前末端默认白色导致亮带），并为 E-07 站补基础材质。失败项从 39 降至 5。
- 限制：本方法按背景像素计算，不考虑描边/阴影对字形的实际增益；波次横幅是瞬时状态；“禁用文字”按 WCAG 可豁免，但这里仍计入并如实列出。
- 报告：`evidence/contrast_report.json`；元素与背景：`evidence/contrast_elements.json`、`shots/contrast/`。

## 6. 性能

**方法**

- 关闭 vsync、`Engine.max_fps=0`；暂停 SceneTree 后分别测 UI 显示/隐藏，差值作为 UI 渲染成本。
- 同一工具在旧 UI worktree `db0b452` 上复跑。
- 环境：RTX 4060 Laptop，1280×720。

| 阶段 | 新 UI p50 / p95 (ms) | 旧 UI p50 / p95 (ms) | 新 Draw p95 | 旧 Draw p95 |
|---|---|---|---|---|
| 菜单显示 | 19.81 / 19.81 | 25.95 / 27.71 | 41 | 320 |
| 菜单隐藏 | 3.48 / 3.48 | 24.40 / 26.96 | 0 | 0 |
| HUD 显示 | 12.96 / 12.96 | 19.55 / 19.55 | 739 | 820 |
| HUD 隐藏 | 10.87 / 10.87 | 17.32 / 17.32 | 625 | 698 |
| 四人 HUD | 19.32 / 19.32 | 未测 | 869 | — |
| UI 差值（菜单，p95） | 16.33 | 1.55 | 41 | 320 |
| UI 差值（HUD，p95） | 2.09 | 2.23 | 114 | 122 |

**结论与限制**

- 总帧时间：新菜单/HUD 均低于旧版；Draw call 明显下降（菜单 41 vs 320，HUD 739 vs 820）。
- HUD UI 差值约 **2.1ms p95**，接近 2ms 目标；菜单 UI 差值约 **16.3ms**，**未达到 2ms 预算**，属于开放问题。
- 旧版“隐藏菜单”仍有约 24ms 基线，导致差值对照不可靠；这是旧版隐藏后仍有渲染/进程工作的证据，不是新 UI 的结论。
- 未采集 Tracy/RenderDoc trace；未在最低规格硬件上测试；所有数字仅代表本机。
- 数据：`evidence/perf_new_final.json`、`evidence/perf_old_paused.json`、`evidence/perf_new_paused.json`、`evidence/perf_old_paused.json`。

## 7. 资产

- `Abandoned_House` 已导入并验证：7 / 0；725 MeshInstance3D、934 surfaces、114,350 顶点、77 材质、70 贴图。
- **未接入任何场景或玩法**；558m 碰撞地面、分散家具、725 网格需要合并/实例化/LOD 后才能使用。
- 授权：原始清单标注“授权不明”，在确认前不得随包发布。
- 详见 `assets/models/abandoned_house/README.md` 与 `assets/PROVENANCE.md`。

## 8. 未完成 / 无法验证

1. 真实玩家可用性测试（5–8 人、录屏、任务计时、3 秒回忆）未执行；只准备了工具包。
2. 真实手柄硬件未测试，不声明支持。
3. 真实 OS 显示缩放（125%/150%）未在 Windows 设置层验证；只做了等效窗口检查。
4. 最低规格硬件、Tracy/RenderDoc、长时间内存/泄漏未测。
5. 故障网络只测 2 人、localhost UDP 代理；未测 4 人、真实 WAN、主机迁移。
6. 对比度仍有 5 项未达 4.5:1；菜单 UI 性能未达 2ms 预算。
7. 本地化、字体缺失、IME、超长文本未测。
8. `Abandoned_House` 授权未确认。
9. 视觉基线依赖本机 GPU/驱动；跨机器比较需重新基线。

## 9. 回退

- `db0b452`：UI v3 之前基线。
- `3d513f3`：UI v3 集成检查点。
- `cc10b99`：Abandoned_House 资产导入检查点。
- `edd19c1`：小地图/可读性修复与验收工具。
- 旧文件备份：`ui_refactor/phase3/baseline/*.bak`。
- 旧 UI 对照 worktree：

```bash
git worktree add /d/tmp/deadcity_old_ui db0b452
```

- 本次未 push 到远端；所有提交均为本地检查点。
