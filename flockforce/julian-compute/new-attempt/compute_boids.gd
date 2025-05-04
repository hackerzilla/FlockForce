extends Node3D

@export var boid_count : int = 100
var boid_scene : PackedScene = load("res://julian-compute/new-attempt/boid.tscn")
@export var spawn_radius : float = 30.0
@export var spawn_velocity : float = 2.0
@export var updates_per_second : int = 2:
	set(new_value):
		updates_per_second = new_value
		update_delay = 1.0 / updates_per_second
var update_delay = 1.0 / 2.0 # to be set by updates_per_second setter
var last_update_time = 0
var quit_requested : bool = false

var rng : RandomNumberGenerator
var boids : Array[RigidBody3D] = []
var pos_arr : PackedFloat32Array
var vel_arr : PackedFloat32Array

# Compute shader stuff
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://julian-compute/new-attempt/compute_boids.glsl") # Adjust path if needed
var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
var shader : RID

var position_buffer_a : RID
var position_buffer_b : RID
var velocity_buffer_a : RID
var velocity_buffer_b : RID
# We have buffers a and b and uniforms made for each
var pos_uniform_a_readonly  : RDUniform 
var pos_uniform_a_writeonly : RDUniform 
var pos_uniform_b_readonly  : RDUniform 
var pos_uniform_b_writeonly : RDUniform 
var vel_uniform_a_readonly  : RDUniform 
var vel_uniform_a_writeonly : RDUniform 
var vel_uniform_b_readonly  : RDUniform 
var vel_uniform_b_writeonly : RDUniform 
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

	# Create buffers
	pos_arr = PackedFloat32Array()
	pos_arr.resize(boid_count * 3)
	vel_arr = PackedFloat32Array()
	vel_arr.resize(boid_count * 3)

	# Initialize boid pos and vel to random
	rng = RandomNumberGenerator.new()
	for i in range(boid_count):
		var boid : RigidBody3D = boid_scene.instantiate()
		add_child(boid)
		boids.push_back(boid)
		var spawn_pos = Vector3(
			rng.randf_range(-spawn_radius, spawn_radius), 
			rng.randf_range(-spawn_radius, spawn_radius), 
			rng.randf_range(-spawn_radius, spawn_radius))
		var spawn_vel = Vector3(
			rng.randf_range(-1.0, 1.0), 
			rng.randf_range(-1.0, 1.0), 
			rng.randf_range(-1.0, 1.0)).normalized() * spawn_velocity # speed constant
		pos_arr[i*3+0] = spawn_pos.x
		pos_arr[i*3+1] = spawn_pos.y
		pos_arr[i*3+2] = spawn_pos.z
		vel_arr[i*3+0] = spawn_vel.x
		vel_arr[i*3+1] = spawn_vel.y
		vel_arr[i*3+2] = spawn_vel.z
		boid.position = spawn_pos
		boid.linear_velocity = spawn_vel
	print("boids initialized [" + str(boids.size()) + "]")

	var pos_byte_arr = pos_arr.to_byte_array()
	var vel_byte_arr = vel_arr.to_byte_array()

	# Create the buffers
	position_buffer_a = rd.storage_buffer_create(pos_byte_arr.size(), pos_byte_arr)
	position_buffer_b = rd.storage_buffer_create(pos_byte_arr.size())
	velocity_buffer_a = rd.storage_buffer_create(vel_byte_arr.size(), vel_byte_arr)
	velocity_buffer_b = rd.storage_buffer_create(vel_byte_arr.size())

	# Create uniforms (bindings: 0=pos in, 1=vel in, 2=pos out, 3=vel out)
	# Position in (readonly) (a)
	pos_uniform_a_readonly = RDUniform.new()
	pos_uniform_a_readonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform_a_readonly.binding = 0
	pos_uniform_a_readonly.add_id(velocity_buffer_a)
	# Position out (writeonly) (a)
	pos_uniform_a_writeonly = RDUniform.new()
	pos_uniform_a_writeonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform_a_writeonly.binding = 2
	pos_uniform_a_writeonly.add_id(velocity_buffer_a)
	# Position in (readonly) (b)
	pos_uniform_b_readonly = RDUniform.new()
	pos_uniform_b_readonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform_b_readonly.binding = 0
	pos_uniform_b_readonly.add_id(velocity_buffer_b)
	# Position out (writeonly) (b)
	pos_uniform_b_writeonly = RDUniform.new()
	pos_uniform_b_writeonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform_b_writeonly.binding = 2
	pos_uniform_b_writeonly.add_id(velocity_buffer_b)

	# Velocity in (readonly) (a)
	vel_uniform_a_readonly = RDUniform.new()
	vel_uniform_a_readonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vel_uniform_a_readonly.binding = 1
	vel_uniform_a_readonly.add_id(velocity_buffer_a)
	# Velocity out (writeonly) (a)
	vel_uniform_a_writeonly = RDUniform.new()
	vel_uniform_a_writeonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vel_uniform_a_writeonly.binding = 3
	vel_uniform_a_writeonly.add_id(velocity_buffer_a)
	# Velocity in (readonly) (b)
	vel_uniform_b_readonly = RDUniform.new()
	vel_uniform_b_readonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vel_uniform_b_readonly.binding = 1
	vel_uniform_b_readonly.add_id(velocity_buffer_b)
	# Velocity out (writeonly) (b)
	vel_uniform_b_writeonly = RDUniform.new()
	vel_uniform_b_writeonly.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vel_uniform_b_writeonly.binding = 3
	vel_uniform_b_writeonly.add_id(velocity_buffer_b)

	# Create uniform sets
	var uniform_arr_read_a_write_b : Array[RDUniform] = [
		pos_uniform_a_readonly,
		vel_uniform_a_readonly,
		pos_uniform_b_writeonly,
		vel_uniform_b_writeonly
	]
	uniform_set_read_a_write_b = rd.uniform_set_create(uniform_arr_read_a_write_b, shader, 0)

	var uniform_arr_read_b_write_a : Array[RDUniform] = [
		pos_uniform_b_readonly,
		vel_uniform_b_readonly,
		pos_uniform_a_writeonly,
		vel_uniform_a_writeonly
	]
	uniform_set_read_b_write_a = rd.uniform_set_create(uniform_arr_read_b_write_a, shader, 0)

	read_a_write_b = true

	# Create pipeline
	pipeline = rd.compute_pipeline_create(shader)

	last_update_time = Time.get_ticks_msec()
	

func _process(_delta: float) -> void:
	if quit_requested:
		free_rendering_resources()
		return
	# Only update <updates_per_second> many times per second 
	var current_time = Time.get_ticks_msec() 
	var msec_since_update = current_time - last_update_time
	var sec_since_update = msec_since_update / 1000.0
	if sec_since_update < update_delay:
		return

	# Update the read-buffers with current positions and velocities
	for i in range(boid_count):
		var base = i * 3
		var boid_pos = boids[i].position
		var boid_vel = boids[i].linear_velocity
		pos_arr[base+0] = boid_pos.x
		pos_arr[base+1] = boid_pos.y
		pos_arr[base+2] = boid_pos.z
		vel_arr[base+0] = boid_vel.x
		vel_arr[base+1] = boid_vel.y
		vel_arr[base+2] = boid_vel.z
	var pos_byte_arr = pos_arr.to_byte_array()
	var vel_byte_arr = vel_arr.to_byte_array()	
	if read_a_write_b:
		rd.buffer_update(position_buffer_a, 0, pos_byte_arr.size(), pos_byte_arr)
		rd.buffer_update(velocity_buffer_a, 0, vel_byte_arr.size(), vel_byte_arr)
	else:
		rd.buffer_update(position_buffer_b, 0, pos_byte_arr.size(), pos_byte_arr)
		rd.buffer_update(velocity_buffer_b, 0, vel_byte_arr.size(), vel_byte_arr)

	# Create the compute list for submission	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	if read_a_write_b:
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_read_a_write_b, 0)
	else:
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_read_b_write_a, 0)
	rd.compute_list_dispatch(compute_list, boid_count, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	var pos_out_bytes 
	var vel_out_bytes 
	# Read the data that was written by the compute shader
	if read_a_write_b:
		pos_out_bytes = rd.buffer_get_data(position_buffer_b)
		vel_out_bytes = rd.buffer_get_data(velocity_buffer_b)
	else:
		pos_out_bytes = rd.buffer_get_data(position_buffer_a)
		vel_out_bytes = rd.buffer_get_data(velocity_buffer_a)
	var position_output = pos_out_bytes.to_float32_array() # Not using for now...
	var velocity_output = vel_out_bytes.to_float32_array()

	for i in range(boid_count):
		var base = i * 3
		var new_pos = Vector3.ZERO # Not using for now
		var new_vel = Vector3.ZERO
		new_pos.x = position_output[base+0]
		new_pos.y = position_output[base+1]
		new_pos.z = position_output[base+2]
		new_vel.x = velocity_output[base+0]
		new_vel.y = velocity_output[base+1]
		new_vel.z = velocity_output[base+2]
		boids[i].linear_velocity = new_vel
		# if i == 5:
			# print("velocity = " + str(new_vel))
	read_a_write_b = not read_a_write_b

	last_update_time = Time.get_ticks_msec()


func _input(event: InputEvent) -> void:
	if event.is_action("Quit"):
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_requested = true
		print("Gracefully quitting...")
		get_tree().quit() # default behavior

func free_rendering_resources() -> void:
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
