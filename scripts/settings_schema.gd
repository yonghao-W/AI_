class_name SettingsSchema
extends RefCounted
## 设置项的唯一数据源：UI、验证、默认值、保存和 InputMap 都从这里读取。

const VERSION := 2

const CATEGORIES := [
	{"id": "controls", "title": "操作与鼠标", "en": "CONTROLS", "description": "调整鼠标响应、瞄准方式与镜头视野。"},
	{"id": "display", "title": "画面与镜头", "en": "DISPLAY", "description": "调整显示方式、帧率与渲染比例。"},
	{"id": "audio", "title": "声音", "en": "AUDIO", "description": "控制已接入 AudioServer 的总音量、音效与界面反馈。"},
	{"id": "hud", "title": "界面与准星", "en": "INTERFACE", "description": "控制战斗信息、准星与反馈的可见性。"},
	{"id": "keybind", "title": "按键绑定", "en": "KEYBINDINGS", "description": "把实际游戏动作绑定到键盘或鼠标。"},
	{"id": "accessibility", "title": "辅助功能", "en": "ACCESSIBILITY", "description": "改善阅读与动态画面舒适度。"},
]

const FIELDS := {
	"mouse_x": {"category": "controls", "type": "slider", "label": "鼠标水平灵敏度", "hint": "左右观察速度", "default": 1.0, "min": 0.10, "max": 3.0, "step": 0.05, "unit": "×", "precision": 2, "description": "直接乘在玩家鼠标水平位移上。1.00× 为工程原始灵敏度；修改后立即影响镜头，不乘帧时间。"},
	"mouse_y": {"category": "controls", "type": "slider", "label": "鼠标垂直灵敏度", "hint": "上下观察速度", "default": 1.0, "min": 0.10, "max": 3.0, "step": 0.05, "unit": "×", "precision": 2, "description": "独立控制上下视角。与水平灵敏度分开保存，适合不同握持习惯。"},
	"ads_sens": {"category": "controls", "type": "slider", "label": "开镜灵敏度倍率", "hint": "瞄准状态下的视角响应", "default": 0.80, "min": 0.20, "max": 1.50, "step": 0.05, "unit": "×", "precision": 2, "description": "仅在真实 aiming 状态乘到鼠标灵敏度上；退出开镜立即恢复基础灵敏度，不改变武器数值。"},
	"fov": {"category": "controls", "type": "slider", "label": "第一人称视野", "hint": "正常状态的 Camera3D FOV", "default": 78, "min": 60, "max": 110, "step": 1, "unit": "°", "precision": 0, "description": "直接控制第一人称 Camera3D 的 FOV。第三人称会在此基础上略收窄，开镜使用独立 ADS FOV。"},
	"ads_fov": {"category": "controls", "type": "slider", "label": "开镜视野", "hint": "ADS 状态的 Camera3D FOV", "default": 58, "min": 45, "max": 75, "step": 1, "unit": "°", "precision": 0, "description": "瞄准时平滑过渡到该 FOV，退出 ADS 回到基础视野。数值越小放大感越强。"},
	"invert_y": {"category": "controls", "type": "toggle", "label": "反转垂直视角", "hint": "交换鼠标上下的镜头方向", "default": false, "description": "只反转垂直视角输入，不影响水平方向或角色移动。"},
	"aim_mode": {"category": "controls", "type": "select", "label": "瞄准操作方式", "hint": "按住或切换瞄准", "default": "hold", "options": [["hold", "按住瞄准"], ["toggle", "切换瞄准"]], "description": "按住：保持右键才瞄准；切换：按一次进入、再按一次退出。退出开镜、倒地或搬运核心时会清理状态。"},

	"window_mode": {"category": "display", "type": "select", "label": "显示模式", "hint": "窗口 / 无边框 / 独占全屏", "default": "windowed", "options": [["windowed", "窗口化"], ["borderless", "无边框全屏"], ["fullscreen", "独占全屏"]], "description": "通过 DisplayServer 实际切换。应用前会要求确认；10 秒内未确认自动恢复原设置。"},
	"resolution": {"category": "display", "type": "select", "label": "分辨率", "hint": "窗口输出尺寸", "default": "1280x720", "options": [["1280x720", "1280 × 720"], ["1600x900", "1600 × 900"], ["1920x1080", "1920 × 1080"], ["2560x1440", "2560 × 1440"]], "description": "窗口模式下实际调用 DisplayServer.window_set_size。独占全屏时由平台决定最终输出尺寸。"},
	"vsync": {"category": "display", "type": "toggle", "label": "垂直同步", "hint": "减少画面撕裂", "default": true, "description": "切换 DisplayServer 的 VSync 模式；与帧率上限共同影响帧时间。"},
	"fps_limit": {"category": "display", "type": "select", "label": "帧率上限", "hint": "限制最高渲染帧率", "default": "0", "options": [["0", "不限制"], ["60", "60 FPS"], ["90", "90 FPS"], ["120", "120 FPS"], ["144", "144 FPS"], ["240", "240 FPS"]], "description": "实际设置 Engine.max_fps；0 表示不限制。"},
	"render_scale": {"category": "display", "type": "slider", "label": "3D 渲染比例", "hint": "内部 3D 渲染分辨率", "default": 1.0, "min": 0.5, "max": 1.0, "step": 0.05, "unit": "%", "precision": 0, "percent": true, "description": "设置根 Viewport 的 scaling_3d_scale；HUD 不受影响。降低可改善性能，但会损失 3D 细节。"},

	"master_volume": {"category": "audio", "type": "slider", "label": "总音量", "hint": "Master Audio Bus", "default": 0.85, "min": 0.0, "max": 1.0, "step": 0.01, "unit": "%", "precision": 0, "percent": true, "description": "控制 Master Bus 的线性音量，0% 时静音。"},
	"sfx_volume": {"category": "audio", "type": "slider", "label": "战斗音效", "hint": "武器、受击、感染者", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01, "unit": "%", "precision": 0, "percent": true, "description": "控制 SFX Bus；武器射击、感染者与战斗反馈已路由到该总线。"},
	"ui_volume": {"category": "audio", "type": "slider", "label": "界面反馈音量", "hint": "菜单与交互提示", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01, "unit": "%", "precision": 0, "percent": true, "description": "控制 UI Bus；换弹、拾取、界面提示等 2D 反馈已路由到该总线。"},

	"hud_scale": {"category": "hud", "type": "slider", "label": "HUD 整体缩放", "hint": "战斗信息尺寸", "default": 1.0, "min": 0.9, "max": 1.1, "step": 0.1, "unit": "%", "precision": 0, "percent": true, "description": "控制 GameHUD 的 _game_layer 缩放，和旧版 90/100/110% 一致。"},
	"hud_opacity": {"category": "hud", "type": "slider", "label": "HUD 背景浓度", "hint": "局部信息背景的浓度", "default": 0.9, "min": 0.4, "max": 1.0, "step": 0.05, "unit": "%", "precision": 0, "percent": true, "description": "只调节 HUD 边缘防背光渐变的 alpha，不覆盖中央战斗视野；文字本身不变。"},
	"crosshair_size": {"category": "hud", "type": "slider", "label": "准星大小", "hint": "准星整体尺寸", "default": 1.0, "min": 0.7, "max": 1.4, "step": 0.05, "unit": "%", "precision": 0, "percent": true, "description": "直接缩放 DeadCrosshair 的绘制尺寸，不是只改设置页示意。"},
	"crosshair_color": {"category": "hud", "type": "select", "label": "准星颜色", "hint": "与环境背景的对比", "default": "white", "options": [["white", "暖白"], ["amber", "琥珀"], ["mint", "浅青"]], "description": "改变实际准星颜色；准星保留黑色阴影，避免只靠颜色。"},
	"crosshair_thickness": {"category": "hud", "type": "slider", "label": "准星线条粗细", "hint": "准星线与中心点", "default": 1.0, "min": 0.6, "max": 2.0, "step": 0.1, "unit": "×", "precision": 1, "description": "直接改变 DeadCrosshair 的线宽与中心点大小。"},
	"hit_marker": {"category": "hud", "type": "toggle", "label": "命中反馈", "hint": "命中时的准星反馈", "default": true, "description": "关闭后仍保留命中音效与伤害数字，只隐藏准星命中标记。"},
	"show_minimap": {"category": "hud", "type": "toggle", "label": "显示小地图", "hint": "战斗中的方向信息", "default": true, "description": "直接隐藏/显示 GameHUD 的小地图，不改变任务或敌人生成。"},
	"show_objective": {"category": "hud", "type": "toggle", "label": "显示任务目标", "hint": "顶部任务摘要", "default": true, "description": "隐藏任务摘要面板；任务逻辑和交互提示仍由服务器/世界逻辑驱动。"},

	"high_contrast": {"category": "accessibility", "type": "toggle", "label": "高对比度界面", "hint": "强化文字与背景边界", "default": false, "description": "HUD 文字使用更重的描边与阴影，菜单背景启用对比层。"},
	"reduced_motion": {"category": "accessibility", "type": "toggle", "label": "减少动态效果", "hint": "关闭非必要位移与呼吸", "default": false, "description": "关闭菜单浮尘、视差、位移过渡和设置页装饰动画；不延迟输入。"},
	"damage_flash": {"category": "accessibility", "type": "slider", "label": "受伤闪烁强度", "hint": "受击与低血的屏幕边缘反馈", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.05, "unit": "%", "precision": 0, "percent": true, "description": "缩放 DamageVignette 的强度；0% 时仍保留生命数值与状态文字，不丢失战斗信息。"},
	"hints": {"category": "accessibility", "type": "toggle", "label": "交互提示", "hint": "靠近物件时的操作提示", "default": true, "description": "关闭后隐藏屏幕底部的交互提示；世界内 Label3D 与任务逻辑不变。"},
}

const CATEGORY_FIELDS := {
	"controls": ["mouse_x", "mouse_y", "ads_sens", "fov", "ads_fov", "invert_y", "aim_mode"],
	"display": ["window_mode", "resolution", "vsync", "fps_limit", "render_scale"],
	"audio": ["master_volume", "sfx_volume", "ui_volume"],
	"hud": ["hud_scale", "hud_opacity", "crosshair_size", "crosshair_color", "crosshair_thickness", "hit_marker", "show_minimap", "show_objective"],
	"keybind": [],
	"accessibility": ["high_contrast", "reduced_motion", "damage_flash", "hints"],
}

const KEY_ACTIONS := {
	"move_forward": {"category": "keybind", "label": "向前移动", "hint": "角色移动", "default": "K:87", "description": "W。迁移到 InputMap 的 move_forward。"},
	"move_back": {"category": "keybind", "label": "向后移动", "hint": "角色移动", "default": "K:83", "description": "S。迁移到 InputMap 的 move_back。"},
	"move_left": {"category": "keybind", "label": "向左移动", "hint": "角色移动", "default": "K:65", "description": "A。迁移到 InputMap 的 move_left。"},
	"move_right": {"category": "keybind", "label": "向右移动", "hint": "角色移动", "default": "K:68", "description": "D。迁移到 InputMap 的 move_right。"},
	"jump": {"category": "keybind", "label": "跳跃", "hint": "移动 / 跳跃", "default": "K:32", "description": "Space。迁移到 InputMap 的 jump。"},
	"sprint": {"category": "keybind", "label": "冲刺", "hint": "按住冲刺", "default": "K:4194325", "description": "Shift。迁移到 InputMap 的 sprint。"},
	"fire": {"category": "keybind", "label": "射击", "hint": "主要武器操作", "default": "M:1", "description": "鼠标左键。迁移到 InputMap 的 fire。"},
	"aim": {"category": "keybind", "label": "瞄准", "hint": "开镜 / ADS", "default": "M:2", "description": "鼠标右键。与瞄准方式（按住/切换）联动。"},
	"reload": {"category": "keybind", "label": "换弹", "hint": "武器操作", "default": "K:82", "description": "R。迁移到 InputMap 的 reload。"},
	"interact": {"category": "keybind", "label": "交互", "hint": "拾取、补给与任务物件", "default": "K:69", "description": "E。主流程的交互请求改由该 action 触发。"},
	"drop_core": {"category": "keybind", "label": "放下核心", "hint": "搬运任务核心", "default": "K:71", "description": "G。主流程的放下核心改由该 action 触发。"},
	"weapon_next": {"category": "keybind", "label": "下一把武器", "hint": "滚轮向下", "default": "W:5", "description": "滚轮向下。迁移到 InputMap 的 weapon_next。"},
	"weapon_prev": {"category": "keybind", "label": "上一把武器", "hint": "滚轮向上", "default": "W:4", "description": "滚轮向上。迁移到 InputMap 的 weapon_prev。"},
	"weapon_1": {"category": "keybind", "label": "武器槽 1", "hint": "主武器", "default": "K:49", "description": "数字 1。迁移到 InputMap 的 weapon_1。"},
	"weapon_2": {"category": "keybind", "label": "武器槽 2", "hint": "副武器", "default": "K:50", "description": "数字 2。迁移到 InputMap 的 weapon_2。"},
	"weapon_3": {"category": "keybind", "label": "武器槽 3", "hint": "第三把武器", "default": "K:51", "description": "数字 3。迁移到 InputMap 的 weapon_3。"},
	"weapon_4": {"category": "keybind", "label": "武器槽 4", "hint": "第四把武器", "default": "K:52", "description": "数字 4。迁移到 InputMap 的 weapon_4。"},
	"weapon_5": {"category": "keybind", "label": "武器槽 5", "hint": "第五把武器", "default": "K:53", "description": "数字 5。迁移到 InputMap 的 weapon_5。"},
	"intel": {"category": "keybind", "label": "战术情报", "hint": "打开/关闭情报", "default": "K:4194306", "description": "Tab。迁移到 InputMap 的 intel。"},
	"backpack": {"category": "keybind", "label": "战术背包", "hint": "打开/关闭背包", "default": "K:66", "description": "B。关闭后恢复输入与鼠标捕获。"},
	"pause": {"category": "keybind", "label": "暂停 / 返回", "hint": "游戏内暂停入口", "default": "K:4194305", "description": "Escape。额外保留 ui_cancel 作为安全返回路径，避免误绑后无法退出。"},
	"ui_confirm": {"category": "keybind", "label": "UI 确认", "hint": "菜单确认 / 激活", "default": "K:4194309", "description": "Enter。写入 InputMap 的 ui_accept；Space 始终保留为安全确认键。"},
	"ui_back": {"category": "keybind", "label": "UI 返回", "hint": "关闭界面 / 返回上级", "default": "K:4194305", "description": "Escape。写入 InputMap 的 ui_cancel；Escape 始终保留为安全返回键。"},
}


static func defaults() -> Dictionary:
	var result := {}
	for key in FIELDS:
		result[key] = FIELDS[key]["default"]
	for action in KEY_ACTIONS:
		result[action] = KEY_ACTIONS[action]["default"]
	return result


static func definition(key: String) -> Dictionary:
	if FIELDS.has(key):
		return FIELDS[key]
	if KEY_ACTIONS.has(key):
		return KEY_ACTIONS[key]
	return {}


static func category_fields(category: String) -> Array:
	if category == "keybind":
		return KEY_ACTIONS.keys()
	return CATEGORY_FIELDS.get(category, [])


static func category_title(category: String) -> String:
	for item in CATEGORIES:
		if item["id"] == category:
			return item["title"]
	return category


static func is_key_action(key: String) -> bool:
	return KEY_ACTIONS.has(key)


static func category_note(category: String) -> String:
	match category:
		"audio":
			return "当前工程没有音乐、语音或独立环境音资源，因此不提供对应滑块；只显示真实存在的 Master、SFX、UI 总线。"
		"display":
			return "阴影质量、抗锯齿与后处理尚未接入可安全运行时切换的渲染路径，因此不在本页伪造。"
		"controls":
			return "当前玩法没有蹲伏；镜头晃动也没有独立控制器，因此不提供无效选项。"
		"accessibility":
			return "当前没有字幕系统，字幕相关设置不在此显示。"
		"keybind":
			return "Esc 取消捕获。暂停始终保留 Escape/ui_cancel 安全返回路径；冲突键会被拒绝。"
		_:
			return ""


static func event_from_string(value: String) -> InputEvent:
	var parts := value.split(":")
	if parts.size() != 2:
		return InputEventKey.new()
	var code := int(parts[1])
	match parts[0]:
		"K":
			var key := InputEventKey.new()
			key.physical_keycode = code
			return key
		"M":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = code
			return mouse
		"W":
			var wheel := InputEventMouseButton.new()
			wheel.button_index = code
			return wheel
		_:
			return InputEventKey.new()


static func string_from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return "K:%d" % code
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return "W:%d" % mouse.button_index if mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] else "M:%d" % mouse.button_index
	return ""


static func event_label(value: String) -> String:
	if value.is_empty():
		return "未绑定"
	var parts := value.split(":")
	if parts.size() != 2:
		return value
	var code := int(parts[1])
	match parts[0]:
		"K":
			return OS.get_keycode_string(code)
		"M":
			match code:
				MOUSE_BUTTON_LEFT: return "鼠标左键"
				MOUSE_BUTTON_RIGHT: return "鼠标右键"
				MOUSE_BUTTON_MIDDLE: return "鼠标中键"
				_: return "鼠标 %d" % code
		"W":
			return "滚轮上" if code == MOUSE_BUTTON_WHEEL_UP else "滚轮下"
	return value
