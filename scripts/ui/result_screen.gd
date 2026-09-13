extends Control

signal claim_pressed

const _Press := preload("res://scripts/ui/press_feedback.gd")

@export var victory_mode: bool = true

@onready var win_root: Control = %WinRoot
@onready var win_waves_value: Label = %WinWavesValue
@onready var win_coins_label: Label = %WinCoinsLabel
@onready var win_claim: Control = %WinClaim
@onready var win_claim_button: TextureButton = %WinClaimButton
@onready var lose_root: Control = %LoseRoot
@onready var lose_waves_value: Label = %LoseWavesValue
@onready var lose_coins_label: Label = %LoseCoinsLabel
@onready var lose_claim: Control = %LoseClaim
@onready var lose_claim_button: TextureButton = %LoseClaimButton
@onready var menu_header: MenuHeader = %MenuHeader


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	win_claim_button.pressed.connect(_on_claim_pressed)
	lose_claim_button.pressed.connect(_on_claim_pressed)
	_Press.bind(win_claim_button, win_claim)
	_Press.bind(lose_claim_button, lose_claim)


func show_result(coins_to_show: int, victory: bool, waves_done: int = -1, waves_total: int = -1) -> void:
	victory_mode = victory

	var done := waves_done
	var total := waves_total
	if done < 0:
		done = GameManager.get_waves_completed()
	if total <= 0:
		total = maxi(GameManager.get_total_waves(), 1)

	win_root.visible = victory
	lose_root.visible = not victory

	var waves_text := "%d\\%d" % [done, total]
	var coins_text := "%d x" % coins_to_show
	if victory:
		win_waves_value.text = waves_text
		win_coins_label.text = coins_text
	else:
		lose_waves_value.text = waves_text
		lose_coins_label.text = coins_text

	if menu_header != null:
		menu_header.refresh()

	visible = true


func hide_result() -> void:
	visible = false


func _on_claim_pressed() -> void:
	claim_pressed.emit()
