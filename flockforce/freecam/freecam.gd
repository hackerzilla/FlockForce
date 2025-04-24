extends Camera3D

@export var move_speed : float = 10.0
@export var mouse_sensitivity: float = 0.003
@export var vertical_angle_limit: float = 85.0

var _min_vertical_angle_rad: float
var _max_vertical_angle_rad: float

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_min_vertical_angle_rad = deg_to_rad(-vertical_angle_limit)
	_max_vertical_angle_rad = deg_to_rad(vertical_angle_limit)


func _process(delta: float) -> void:
	var move_input : Vector2 = Input.get_vector(
		"Move Left", "Move Right","Move Forward", "Move Backward")
	var move_dir : Vector3 = Vector3(move_input.x, 0, move_input.y)
	
	if move_dir:
		translate(move_dir * delta * move_speed)

func _input(event: InputEvent) -> void:
	if event.is_action("Quit"):
		get_tree().quit()
	if event is InputEventMouseMotion:
		self.rotate_y(-event.relative.x * mouse_sensitivity)
		self.rotate_x(-event.relative.y * mouse_sensitivity)
		self.rotation.x = clamp(self.rotation.x, _min_vertical_angle_rad, _max_vertical_angle_rad)
		self.rotation.z = 0
