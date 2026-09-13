extends Control

@onready var hp_bar: ProgressBar = $HpBar
@onready var hp_value: Label = $HpCluster/HpValue


func update_hp(new_hp: float, max_hp: float) -> void:
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = new_hp
	if hp_value != null:
		hp_value.text = str(maxi(int(round(new_hp)), 0))
