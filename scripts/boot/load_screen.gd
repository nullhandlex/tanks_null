extends Control

## First frame is on-screen immediately. The loop starts as soon as frames load.

const MENU_SCENE := "res://scenes/main_menu/MainMenu.tscn"
const FRAMES_PATH := "res://resources/sprite_frames/ui/load_screen.tres"
const FRAME_SIZE := Vector2(1080.0, 1920.0)
const FRAME_COUNT := 40
const FPS := 12.0
const LOOP_SEC := float(FRAME_COUNT) / FPS
const FAILSAFE_SEC := 8.0

@onready var still: TextureRect = $Still
@onready var anim: AnimatedSprite2D = $World/Anim

var _anim_elapsed: float = 0.0
var _anim_playing: bool = false
var _total_elapsed: float = 0.0
var _menu: PackedScene = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit_anim)
	_fit_anim()
	ResourceLoader.load_threaded_request(FRAMES_PATH)
	ResourceLoader.load_threaded_request(MENU_SCENE)


func _process(delta: float) -> void:
	_total_elapsed += delta
	if not _anim_playing:
		_try_start_anim()
	else:
		_anim_elapsed += delta
	if _menu == null:
		_try_take_menu()
	var loop_done := _anim_playing and _anim_elapsed >= LOOP_SEC
	if _menu != null and (loop_done or _total_elapsed >= FAILSAFE_SEC):
		get_tree().change_scene_to_packed(_menu)


func _try_start_anim() -> void:
	var status := ResourceLoader.load_threaded_get_status(FRAMES_PATH)
	var frames: SpriteFrames = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		frames = ResourceLoader.load_threaded_get(FRAMES_PATH) as SpriteFrames
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		frames = load(FRAMES_PATH) as SpriteFrames
	if frames == null or anim == null:
		return
	anim.sprite_frames = frames
	anim.animation = &"load"
	anim.visible = true
	anim.play(&"load")
	if still != null:
		still.visible = false
	_anim_playing = true
	_fit_anim()


func _try_take_menu() -> void:
	var status := ResourceLoader.load_threaded_get_status(MENU_SCENE)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_menu = ResourceLoader.load_threaded_get(MENU_SCENE)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		_menu = load(MENU_SCENE) as PackedScene


func _fit_anim() -> void:
	if anim == null:
		return
	var view := size
	if view.x < 2.0 or view.y < 2.0:
		view = get_viewport_rect().size
	var scale := maxf(view.x / FRAME_SIZE.x, view.y / FRAME_SIZE.y)
	anim.position = view * 0.5
	anim.scale = Vector2(scale, scale)
