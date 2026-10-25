# Phase 3 证据索引

代码基准：`c18b286` · Godot 4.7.2 · 2026-10-25

## 文件

| 文件 | 内容 |
|---|---|
| `baseline_manifest.json` | 13 状态 × 4 分辨率共 52 张基线；commit、分辨率、seed、SHA-256、生成命令 |
| `current_manifest.json` | 同一矩阵的复跑清单 |
| `visual_diff.json` | 基线 vs 复跑逐像素差异；阈值 0.15%；本次 0 失败；同代码复跑菜单噪声最高 0.103% |
| `perf_new_final.json` | 新 UI：菜单/HUD 显示与隐藏的 p50/p95/p99、Draw call、UI 差值 |
| `perf_old_paused.json` | 旧 UI（`db0b452` worktree）同工具对照 |
| `perf_new_paused.json` / `perf_new_unpaused.json` / `perf_old_unpaused.json` | 中间采样，保留用于说明测量差异；文档以 `perf_new_final.json` 与 `perf_old_paused.json` 为准 |
| `contrast_elements.json` | 11 状态、250 个有效文字元素的字号/字色/矩形与文字隐藏后的背景 |
| `contrast_report.json` | 逐元素 WCAG 对比度，5 项低于阈值 |
| `network/adverse_host.txt` | 150ms RTT/2%/30ms 抖动下 300s 房主日志（175 检查） |
| `network/adverse_client.txt` | 同条件客户端日志（172 检查） |
| `network/adverse_proxy.txt` | UDP 代理统计（4184 up / 9997 down / 315 dropped） |

## 基线图

- 路径：`ui_refactor/phase3/baselines/`。
- 已在 `.gitignore` 中忽略（52 张 PNG 体积较大）；可用 `baseline_manifest.json` 中的 SHA-256 校验，或按下面命令从 `c18b286` 重建（manifest 已记录该提交号）。
- 视觉比较时使用隔离模式：减少动效、隐藏 3D 世界、暂停 SceneTree、隐藏瞬时波次横幅、固定 seed 4242。

## 复现命令

```bash
# 基线
Godot --path . --resolution 640x360 \
  --script res://ui_refactor/phase3/tools/capture_ui_matrix.gd -- \
  --out=ui_refactor/phase3/baselines \
  --manifest=ui_refactor/phase3/evidence/baseline_manifest.json \
  --commit=$(git rev-parse --short HEAD)

# 对比度
Godot --path . --resolution 640x360 \
  --script res://ui_refactor/phase3/tools/contrast_audit.gd -- \
  --commit=$(git rev-parse --short HEAD)
python ui_refactor/phase3/tools/contrast_report.py

# 性能
Godot --path . --resolution 1280x720 \
  --script res://ui_refactor/phase3/tools/perf_ui.gd -- \
  --out=ui_refactor/phase3/evidence/perf_new_final.json \
  --commit=$(git rev-parse --short HEAD)

# 故障网络（三个终端）
python ui_refactor/phase3/tools/udp_delay_proxy.py \
  --listen 17891 --target 17890 --delay-ms 75 --jitter-ms 30 --loss 0.02 --seconds 330
Godot --headless --path . --script res://tests/test_ui_network.gd -- \
  --host --host-port=17890 --join-port=17890 --soak=300
Godot --headless --path . --script res://tests/test_ui_network.gd -- \
  --join-port=17891 --soak=300
```

## 读数注意

- 性能测量受窗口焦点、GPU 驱动与 vsync 影响；本报告已关闭 vsync 并冻结 SceneTree，但仍存在基线差异。菜单 UI 差值 16.3ms 未达 2ms 预算，是开放问题。
- 对比度按背景像素计算，不考虑描边/阴影增益；波次横幅是瞬时状态；禁用文字按 WCAG 可豁免，但报告仍计入。
- 故障网络是 localhost UDP 代理，不是真实 WAN；只测 2 人。
- 视觉基线依赖本机 GPU/驱动；跨机器必须重建基线。
