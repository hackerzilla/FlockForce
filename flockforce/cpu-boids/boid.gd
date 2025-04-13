@tool
extends RigidBody3D
class_name Boid

@onready var arrow_pivot = $ArrowPivot

func _process(delta: float) -> void:
	arrow_pivot.look_at(linear_velocity + global_position)
	
