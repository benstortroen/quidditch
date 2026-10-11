extends Node3D

@export var player : Node3D


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	look_at(player.position, Vector3.UP)
