# Abandoned_House 导入资产

- **来源**：`E:\游戏练手项目\末日探索\场景素材\Abandoned_House\Models\Abandoned_House.glb`
- **导入日期**：2026-10-24
- **工程路径**：`res://assets/models/abandoned_house/abandoned_house.glb`（12,915,868 字节）
- **许可**：原始清单标注“授权不明”（原路径 `D:\BaiduNetdisk\CWM\Abandoned_House`）。**在确认授权前不得随包发布或商用。**

## 结构

- glTF 2.0，Blender glTF I/O 4.1.63，自包含 74 张内嵌贴图。
- 源文件：753 nodes / 568 meshes / 777 primitives / 111,838 顶点。
- 导入后：725 MeshInstance3D / 934 surfaces / 114,350 顶点 / 77 材质 / 70 张独立贴图。

## 场景内容

- `Casa`：房屋外壳，约 44 × 12.6 × 45 m。
- `grass`：庭院地面，约 45 × 45 m。
- `Vecindario`：街区与远景，约 558 × 558 m；另有一个 558 m 的 `Colision` 碰撞地面。
- 室内陈设是多个独立组（`Sillones`、`Sillas`、`Mesas`、`Baño`、`Lamparas` 等），并未合并成可直接游玩的室内；隐藏 `Casa` 后可见家具分布分散、存在悬空与重复。
- 规模最大的组：`grass` 158 个网格、`Casa` 70、`Telarañas` 67、`Cajones_Puertas` 64、`Trash` 37。

## 导入产物

Godot 在 GLB 旁提取了 77 张贴图及对应 `.import` 文件，并生成 `abandoned_house.glb.import`。这些文件是导入资源的一部分，不要单独移动或删除。

## 验证

- `tests/test_abandoned_house_asset.gd`：7 checks / 0 failures。
- 预览工具：`ui_refactor/phase3/tools/preview_asset.gd`
  ```
  Godot --path . --resolution 1280x720 \
    --script res://ui_refactor/phase3/tools/preview_asset.gd -- \
    --exclude=Colision --exclude=Vecindario --focus=Casa \
    --out=res://ui_refactor/phase3/shots/asset_preview/shell.png
  ```
- 预览图：`ui_refactor/phase3/shots/asset_preview/`
  - `abandoned_house_exterior_1280x720.png`
  - `abandoned_house_shell_1280x720.png`
  - `abandoned_house_interior_1280x720.png`
  - `abandoned_house_interior_close_1280x720.png`

## 现状与接入约束

- 仅完成导入、加载和渲染验证，**未接入任何场景、菜单或玩法逻辑**。
- 725 个 MeshInstance3D 直接进关卡会产生大量 draw call，接入前必须合并、实例化或做 LOD。
- `Colision` 的 558 m 碰撞地面不能直接带入玩法场景。
- 室内家具需要人工筛选、重排和碰撞体制作，不能整包当成品房屋使用。
- 授权未确认前只能作为内部参考/原型素材。
