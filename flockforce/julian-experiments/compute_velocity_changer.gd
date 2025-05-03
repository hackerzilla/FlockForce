extends Node3D

@export var updates_per_second : int = 2:
	set(new_value):
		updates_per_second = new_value
		update_delay = 1.0 / updates_per_second
var update_delay = 1.0 / 2.0 # to be set by updates_per_second setter
var last_update_time = 0

var plane_body : RigidBody3D 
var initial_velocity : Vector3 = Vector3.ZERO

# Compute shader stuff
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://julian-experiments/compute_velocity_changer.glsl") # Adjust path if needed
var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
var shader : RID
var velocity_buffer_a : RID
var velocity_buffer_b : RID
var uniform_a : RDUniform 
var uniform_b : RDUniform 
var uniform_set_read_a_write_b : RID
var uniform_set_read_b_write_a : RID
var read_a_write_b : bool = true # for buffer swapping
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

	plane_body = $RigidBody3D
	initial_velocity = plane_body.linear_velocity
	print("Initial velocity of body is: ", str(initial_velocity))

	# Create buffers
	var vel_arr = PackedFloat32Array()
	vel_arr.resize(3)
	vel_arr[0] = initial_velocity[0]
	vel_arr[1] = initial_velocity[1]
	vel_arr[2] = initial_velocity[2]
	var vel_byte_arr = vel_arr.to_byte_array()
	velocity_buffer_a = rd.storage_buffer_create(vel_byte_arr.size(), vel_byte_arr)
	velocity_buffer_b = rd.storage_buffer_create(vel_byte_arr.size())

	# Create uniforms
	uniform_a = RDUniform.new()
	uniform_a.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_a.binding = 0
	uniform_a.add_id(velocity_buffer_a)

	uniform_b = RDUniform.new()
	uniform_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_b.binding = 1
	uniform_b.add_id(velocity_buffer_b)

	# Create uniform sets
	uniform_set_read_a_write_b = rd.uniform_set_create([uniform_a, uniform_b], shader, 0)
	uniform_set_read_b_write_a = rd.uniform_set_create([uniform_b, uniform_a], shader, 0)
	read_a_write_b = true

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

	# Update the read-buffer with current velocity
	var curr_velocity = plane_body.linear_velocity
	var vel_arr = PackedFloat32Array()
	vel_arr.resize(3)
	vel_arr[0] = curr_velocity[0]
	vel_arr[1] = curr_velocity[1]
	vel_arr[2] = curr_velocity[2]
	var vel_byte_arr = vel_arr.to_byte_array()	
	if read_a_write_b:
		rd.buffer_update(velocity_buffer_a, 0, vel_byte_arr.size(), vel_byte_arr)
	else:
		rd.buffer_update(velocity_buffer_b, 0, vel_byte_arr.size(), vel_byte_arr)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	if read_a_write_b:
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_read_a_write_b, 0)
	else:
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_read_b_write_a, 0)
	rd.compute_list_dispatch(compute_list, 1, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	var output_bytes
	if read_a_write_b:
		output_bytes = rd.buffer_get_data(velocity_buffer_b)
	else:
		output_bytes = rd.buffer_get_data(velocity_buffer_a)
	var velocity_output = output_bytes.to_float32_array()
	var new_velocity = Vector3.ZERO
	new_velocity[0] = velocity_output[0]
	new_velocity[1] = velocity_output[1]
	new_velocity[2] = velocity_output[2]

	plane_body.linear_velocity = new_velocity

	read_a_write_b = not read_a_write_b

	last_update_time = Time.get_ticks_msec()

	# print("velocity updated with value: ", str(new_velocity))

func _input(event: InputEvent) -> void:
	if event.is_action("Quit"):
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Free the resources we accumulated
		if velocity_buffer_a:
			rd.free_rid(velocity_buffer_a)
		if velocity_buffer_b:
			rd.free_rid(velocity_buffer_b)
		if pipeline:
			rd.free_rid(pipeline)
		if uniform_set_read_a_write_b:
			rd.free_rid(uniform_set_read_a_write_b)
		if uniform_set_read_b_write_a:
			rd.free_rid(uniform_set_read_b_write_a)
		print("Gracefully quitting...")
		get_tree().quit() # default behavior
