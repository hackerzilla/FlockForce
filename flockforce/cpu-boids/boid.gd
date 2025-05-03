@tool
extends RigidBody3D
class_name Boid

@onready var arrow_pivot = $ArrowPivot

func _process(delta: float) -> void:
	var target = linear_velocity + global_position
	var safe_to_look : bool = \
		target != global_position and \
		linear_velocity != transform.basis.z
	if safe_to_look:
		arrow_pivot.look_at(target)
	
