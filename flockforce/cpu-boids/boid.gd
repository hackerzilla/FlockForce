@tool
extends RigidBody3D
class_name Boid

@onready var arrow_pivot = $ArrowPivot

func _process(delta: float) -> void:
	var target = linear_velocity + global_position
	if target != global_position:
		arrow_pivot.look_at(target)
	
