extends Node2D

@onready var ring: Sprite2D = $Ring
@onready var spark_particles: CPUParticles2D = $SparkParticles


func _ready() -> void:
	spark_particles.emitting = true
	ring.scale = Vector2(0.4, 0.4)
	ring.modulate = Color(1.0, 0.95, 0.45, 0.95)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)
