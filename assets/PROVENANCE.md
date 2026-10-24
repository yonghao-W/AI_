# 资产来源与许可清单

更新：2026-10-24 · 代码基准 `edd19c1`

> 原则：未确认授权的资产只能用于内部原型/研究，不得随包发布或商用。此清单不替代法律审查。

## 随工程资产

| 资产 | 路径 | 来源 | 许可/状态 |
|---|---|---|---|
| E-07 主菜单背景 | `assets/ui/menu/e07_observation_exterior.webp` | Qoder CN 会话中的概念图，生成方式未记录 | **UNVERIFIED / 概念占位**；无烘焙文字；发行前需替换或补授权 |
| E-07 维护站场景 | `assets/chapter_01/e07_station.glb`、`e07_design.json` | 项目内制作/生成，具体来源未记录 | **待补证**；仅项目内部使用 |
| Abandoned_House | `assets/models/abandoned_house/` | `E:\游戏练手项目\末日探索\场景素材\Abandoned_House`；原 `D:\BaiduNetdisk\CWM\Abandoned_House` | **授权不明**；见同目录 README；不得随包发布 |
| 项目图标 | `icon.svg` | 项目内 | 项目资产 |
| UI 截图/基线 | `ui_refactor/**/shots/`、`baselines/` | Godot 实际渲染 | 项目内取证；不含第三方素材 |
| 参考游戏截图 | `ui_refactor/phase1/refs/*.jpg` | Interface In Game 等公开页面 | **仅研究参考**，不随包、不用于宣传 |

## 未随工程但相关的素材

| 素材 | 位置 | 许可状态 |
|---|---|---|
| AJ_ASSET_LAB（Minecraft 地图/世界） | `E:\游戏练手项目\末日探索\地图工程\AJ_ASSET_LAB` | 内部记录 ZZAM（MIT）、ITV1、TZA_X；但 Minecraft 地图/整合包与 Mojang EULA 仍需单独确认 |
| 其他游戏练手素材 | `E:\游戏练手项目\KaCa`、`变形者`、`ChronoRoom`、`新游戏项目` | 各自来源/许可未在本清单确认 |
| 建模归档 | `D:\建模归档` | 旧入口为目录链接，实际文件在 E 盘 |

## 字体

- 全部使用 `SystemFont`（微软雅黑/思源黑体/宋体等系统字体），**不分发字体文件**。
- 若未来打包分发或替换为随包字体，必须补充字体许可与 CJK 字形覆盖检查。

## 第三方引用

- 设计参考只学习方法，不复制布局、图标、美术资产或品牌元素。
- 参考截图（TLOU/Detroit）仅用于内部证据库，不进入游戏包、商店页或宣传素材。
- AI/概念图不得冒充已完成的 3D 场景或实际运行截图。

## 待办

- [ ] 确认 E-07 背景的生成方式与商用许可，或替换为 Blender 产出
- [ ] 确认 Abandoned_House 授权；未确认前只做内部原型
- [ ] 确认 `e07_station.glb` 的制作来源与许可
- [ ] 若发行，补齐字体与第三方素材清单
