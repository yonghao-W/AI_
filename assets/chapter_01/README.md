# 第一章 · 失联信号

`e07_station.glb` 来自用户提供的 `E07_Chapter1_Building_Pack.zip` 中的完整建筑白模，`e07_design.json` 是同包原始设计参数。剖视模型不进入游戏。

运行入口仍是 `scenes/main.tscn`。主菜单“开始第一章”或创建房间后开始，从维护站三楼出发；死亡后的复活点仍是基地。当前目标为楼内探索、下楼到基地、公园 B1 回收三枚核心并交付。维护站地下配电层与公园核心储藏层是两个独立空间。

`scripts/chapter_one_station.gd` 负责朝向修正、城市地块预留、建筑碰撞、连续楼梯碰撞、出口平台、无线电提示与窗外高架占位。原始 GLB 保持不变，运行时将其 Z-up 转成 Godot Y-up。地块中心是 Godot 坐标 `(80, 0, -80)`，其他街区继续按种子生成。

这是可玩灰盒。材质、道具、演出和关卡战斗节奏仍需继续制作；高架是窗外布景，城市围墙限制不变。

验证：使用 Godot 4.7.2 执行 `--headless --path <工程目录> --script res://tests/test_chapter_one.gd`。现有任务与城市回归分别是 `tests/test_mission.gd`、`tests/test_city_layout.gd`。

两进程联机回归使用 `tests/test_chapter_network.gd`，先启动带 `-- --host` 的进程，再启动不带该参数的客户端，测试端口为 17877。实机预览由 `tests/preview_chapter_one.gd` 输出到 `shots/chapter_one_observation.png`、`shots/chapter_one_exterior.png`。
