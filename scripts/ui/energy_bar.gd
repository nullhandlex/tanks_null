extends Control

## Battle ult meter. GameManager pushes fill via `set_fill_ratio`.
## Soft static glow while charging; a pulse at 50% (MG) and a stronger
## pulse at 100% (cannon).

enum ReadyTier { NONE, MG, CANNON }

const CHARGE_GLOW := Color(1.15, 0.95, 0.45, 1.0)
const MG_GLOW_LO := Color(2.2, 1.45, 0.35, 0.95)
const MG_GLOW_HI := Color(3.6, 2.4, 0.7, 1.0)
const MG_BLOOM_LO := Color(1.8, 1.05, 0.2, 0.7)
const MG_BLOOM_HI := Color(3.0, 1.9, 0.45, 1.0)
const MG_FILL_LO := Color(1.25, 1.05, 0.7, 1.0)
const MG_FILL_HI := Color(1.95, 1.55, 0.75, 1.0)
const MG_BOLT_LO := Color(1.25, 1.05, 0.7, 1.0)
const MG_BOLT_HI := Color(2.05, 1.7, 0.85, 1.0)

const CANNON_GLOW_LO := Color(2.8, 1.9, 0.55, 1.0)
const CANNON_GLOW_HI := Color(4.6, 3.4, 1.4, 1.0)
const CANNON_BLOOM_LO := Color(2.4, 1.5, 0.35, 0.85)
const CANNON_BLOOM_HI := Color(4.2, 2.8, 0.9, 1.0)
const CANNON_FILL_LO := Color(1.55, 1.2, 0.65, 1.0)
const CANNON_FILL_HI := Color(2.5, 2.15, 1.25, 1.0)
const CANNON_BOLT_LO := Color(1.55, 1.25, 0.75, 1.0)
const CANNON_BOLT_HI := Color(2.4, 2.15, 1.35, 1.0)

@onready var track: TextureProgressBar = $Track
@onready var glow: TextureRect = $Glow
@onready var bloom: TextureRect = $Bloom
@onready var bolt: TextureRect = $Bolt

var _tier: ReadyTier = ReadyTier.NONE
var _pulse: Tween
var _fill: float = 0.0


func _ready() -> void:
	_center_glow_pivots()
	_ensure_add_blend(glow)
	_ensure_add_blend(bloom)
	_apply_tier(ReadyTier.NONE, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_glow_pivots()


func _center_glow_pivots() -> void:
	if glow != null:
		glow.pivot_offset = glow.size * 0.5
	if bloom != null:
		bloom.pivot_offset = bloom.size * 0.5
	if bolt != null:
		bolt.pivot_offset = bolt.size * 0.5


func _ensure_add_blend(rect: TextureRect) -> void:
	if rect == null or rect.material != null:
		return
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rect.material = add


func set_fill_ratio(ratio: float) -> void:
	_fill = clampf(ratio, 0.0, 1.0)
	if track != null:
		track.value = _fill * track.max_value
	_apply_tier(_tier_from_fill(_fill))


func _tier_from_fill(ratio: float) -> ReadyTier:
	var current := ratio * GameManager.MAX_ENERGY
	if current >= GameManager.CANNON_ULT_COST - 0.01:
		return ReadyTier.CANNON
	if current >= GameManager.MG_ULT_COST - 0.01:
		return ReadyTier.MG
	return ReadyTier.NONE


func _apply_tier(tier: ReadyTier, force: bool = false) -> void:
	if not force and _tier == tier:
		if tier == ReadyTier.NONE:
			_apply_charge_glow()
		return
	_tier = tier
	_restart_pulse()


func _apply_charge_glow() -> void:
	if glow != null:
		glow.visible = _fill > 0.001
		glow.scale = Vector2.ONE
		var tint := CHARGE_GLOW
		tint.a = 0.22 * _fill
		glow.modulate = tint
	if bloom != null:
		bloom.visible = false
		bloom.scale = Vector2.ONE
	if track != null:
		track.modulate = Color.WHITE
	if bolt != null:
		bolt.modulate = Color.WHITE
		bolt.scale = Vector2.ONE


func _restart_pulse() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if glow != null:
		glow.scale = Vector2.ONE
	if bloom != null:
		bloom.scale = Vector2.ONE
	if bolt != null:
		bolt.modulate = Color.WHITE
		bolt.scale = Vector2.ONE
	if track != null:
		track.modulate = Color.WHITE

	if _tier == ReadyTier.NONE:
		_apply_charge_glow()
		return

	_center_glow_pivots()
	if glow != null:
		glow.visible = true
	if bloom != null:
		bloom.visible = true

	var glow_lo := MG_GLOW_LO
	var glow_hi := MG_GLOW_HI
	var bloom_lo := MG_BLOOM_LO
	var bloom_hi := MG_BLOOM_HI
	var fill_lo := MG_FILL_LO
	var fill_hi := MG_FILL_HI
	var bolt_lo := MG_BOLT_LO
	var bolt_hi := MG_BOLT_HI
	var period := 0.5
	var glow_scale := Vector2(1.35, 1.12)
	var bloom_scale := Vector2(1.2, 1.1)
	var bolt_scale := Vector2(1.12, 1.12)
	if _tier == ReadyTier.CANNON:
		glow_lo = CANNON_GLOW_LO
		glow_hi = CANNON_GLOW_HI
		bloom_lo = CANNON_BLOOM_LO
		bloom_hi = CANNON_BLOOM_HI
		fill_lo = CANNON_FILL_LO
		fill_hi = CANNON_FILL_HI
		bolt_lo = CANNON_BOLT_LO
		bolt_hi = CANNON_BOLT_HI
		period = 0.28
		glow_scale = Vector2(1.55, 1.18)
		bloom_scale = Vector2(1.35, 1.16)
		bolt_scale = Vector2(1.22, 1.22)

	if glow != null:
		glow.modulate = glow_lo
	if bloom != null:
		bloom.modulate = bloom_lo
	if track != null:
		track.modulate = fill_lo
	if bolt != null:
		bolt.modulate = bolt_lo

	_pulse = create_tween().set_loops()
	_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if glow != null:
		_pulse.tween_property(glow, "modulate", glow_hi, period)
		_pulse.parallel().tween_property(glow, "scale", glow_scale, period)
	if bloom != null:
		_pulse.parallel().tween_property(bloom, "modulate", bloom_hi, period)
		_pulse.parallel().tween_property(bloom, "scale", bloom_scale, period)
	if track != null:
		_pulse.parallel().tween_property(track, "modulate", fill_hi, period)
	if bolt != null:
		_pulse.parallel().tween_property(bolt, "modulate", bolt_hi, period)
		_pulse.parallel().tween_property(bolt, "scale", bolt_scale, period)
	if glow != null:
		_pulse.tween_property(glow, "modulate", glow_lo, period)
		_pulse.parallel().tween_property(glow, "scale", Vector2.ONE, period)
	if bloom != null:
		_pulse.parallel().tween_property(bloom, "modulate", bloom_lo, period)
		_pulse.parallel().tween_property(bloom, "scale", Vector2.ONE, period)
	if track != null:
		_pulse.parallel().tween_property(track, "modulate", fill_lo, period)
	if bolt != null:
		_pulse.parallel().tween_property(bolt, "modulate", bolt_lo, period)
		_pulse.parallel().tween_property(bolt, "scale", Vector2.ONE, period)
