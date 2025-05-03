extends Node3D

@export var updates_per_second : int = 2:
	set(new_value):
		updates_per_second = new_value
		update_delay = 1.0 / updates_per_second
var update_delay = 1.0 / 2.0 # to be set by updates_per_second setter
var last_update_time = 0

var plane_mesh : MeshInstance3D
var plane_material : StandardMaterial3D
var initial_color : Vector3 = Vector3.ZERO

# Compute shader stuff
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://julian-experiments/compute_color_changer.glsl") # Adjust path if needed
var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
var shader : RID
var color_buffer : RID
var uniform : RDUniform 
var uniform_set : RID
var pipeline : RID

func _ready() -> void:
	# Initialize compute shader stuff
	if rd == null:
		print("Bad news (Failed to create local rendering device)")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		return

	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		printerr("Ruh roh! (Failed to create shader)")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		return

	plane_mesh = $MeshInstance3D
	plane_material = plane_mesh.get_active_material(0)
	var col = plane_material.albedo_color
	initial_color = Vector3(col.r, col.g, col.b)

	# Create buffers
	var col_arr = PackedFloat32Array()
	col_arr.resize(3)
	col_arr[0] = initial_color[0]
	col_arr[1] = initial_color[1]
	col_arr[2] = initial_color[2]
	var col_arr_bytes = col_arr.to_byte_array()
	color_buffer = rd.storage_buffer_create(col_arr_bytes.size(), col_arr_bytes)

	# Create uniforms
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(color_buffer)

	# Create uniform set
	uniform_set = rd.uniform_set_create([uniform], shader, 0)

	# Create pipeline
	pipeline = rd.compute_pipeline_create(shader)

	last_update_time = Time.get_ticks_msec()
	

func _process(_delta: float) -> void:
	# Only update x times per second (see updates_per_second)
	var current_time = Time.get_ticks_msec() 
	var msec_since_update = current_time - last_update_time
	var sec_since_update = msec_since_update / 1000.0
	if sec_since_update < update_delay:
		return
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 1, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	var output_bytes = rd.buffer_get_data(color_buffer)
	var color_output = output_bytes.to_float32_array()
	var new_color = Color.BLACK
	new_color[0] = color_output[0]
	new_color[1] = color_output[1]
	new_color[2] = color_output[2]

	plane_material.albedo_color = new_color

	# print("Red channel = ", str(new_color[0])) 

	last_update_time = Time.get_ticks_msec()

func _input(event: InputEvent) -> void:
	if event.is_action("Quit"):
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Gracefully quitting...")
		get_tree().quit() # default behavior
