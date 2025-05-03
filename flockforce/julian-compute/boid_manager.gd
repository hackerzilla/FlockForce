extends Node

@export var boid_scene: PackedScene
@export var boid_count: int = 10 
@export var spawn_radius: float = 50.0
@export var updates_per_second : int = 2:
	set(new_value):
		updates_per_second = new_value
		update_delay = 1.0 / updates_per_second

# Keep user's original RigidBody3D type hint
var boids: Array[RigidBody3D] = []

# Rendering Device setup
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://julian-compute/compute_boid.glsl") # Adjust path if needed
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader: RID

# --- Swap Buffer Resources ---
var pos_buffer_a: RID
var vel_buffer_a: RID
var pos_buffer_b: RID
var vel_buffer_b: RID
var params_buffer: RID
var uniform_set_a: RID # Reads A, Params; Writes B
var uniform_set_b: RID # Reads B, Params; Writes A
var pipeline: RID
var current_set_is_a := true # Start reading from A

# Others
var rng
var pos_start_arr
var vel_start_arr
var update_delay : float = 0.0 # in seconds
var last_update_time = 0.0

func create_storage_uniform(binding: int, buffer_rid: RID) -> RDUniform:
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer_rid)
	return uniform

func _ready():
	if rd == null:
		printerr("Failed to create local RenderingDevice.")
		get_tree().quit()
		return

	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		printerr("Failed to create shader.")
		get_tree().quit()
		return

	# Initialize Data
	rng = RandomNumberGenerator.new()
	pos_start_arr = PackedFloat32Array()
	vel_start_arr = PackedFloat32Array()
	pos_start_arr.resize(boid_count * 3)
	vel_start_arr.resize(boid_count * 3)

	for i in range(boid_count):
		var spawn_pos = Vector3(
			rng.randf_range(-spawn_radius, spawn_radius), 
			rng.randf_range(-spawn_radius, spawn_radius), 
			rng.randf_range(-spawn_radius, spawn_radius)
		)
		var spawn_vel = Vector3(
			rng.randf_range(-1.0, 1.0), 
			rng.randf_range(-1.0, 1.0), 
			rng.randf_range(-1.0, 1.0)
		).normalized() * 5.0 # Example start speed

		pos_start_arr[i*3+0] = spawn_pos.x
		pos_start_arr[i*3+1] = spawn_pos.y
		pos_start_arr[i*3+2] = spawn_pos.z
		vel_start_arr[i*3+0] = spawn_vel.x
		vel_start_arr[i*3+1] = spawn_vel.y
		vel_start_arr[i*3+2] = spawn_vel.z

	var position_bytes = pos_start_arr.to_byte_array()
	var velocity_bytes = vel_start_arr.to_byte_array()

	# Create Buffers
	pos_buffer_a = rd.storage_buffer_create(position_bytes.size(), position_bytes)
	vel_buffer_a = rd.storage_buffer_create(velocity_bytes.size(), velocity_bytes)
	pos_buffer_b = rd.storage_buffer_create(position_bytes.size()) # Empty, for first write
	vel_buffer_b = rd.storage_buffer_create(velocity_bytes.size()) # Empty, for first write

	# Parameter buffer (boid_count: int, delta: float)
	var params_data = PackedByteArray()
	params_data.resize(4 + 4) # int + float
	params_data.encode_s32(0, boid_count)
	params_data.encode_float(4, 0.0) # Initial delta
	params_buffer = rd.storage_buffer_create(params_data.size(), params_data)

	# We make two uniform sets to implement buffer swapping
	# Set A: Read A (0,1), Params (2), Write B (3,4)
	var uniforms_a: Array[RDUniform] = [
		create_storage_uniform(0, pos_buffer_a),
		create_storage_uniform(1, vel_buffer_a),
		create_storage_uniform(2, params_buffer),
		create_storage_uniform(3, pos_buffer_b),
		create_storage_uniform(4, vel_buffer_b)
	]
	uniform_set_a = rd.uniform_set_create(uniforms_a, shader, 0)

	# Set B: Read B (0,1), Params (2), Write A (3,4)
	var uniforms_b: Array[RDUniform] = [
		create_storage_uniform(0, pos_buffer_b),
		create_storage_uniform(1, vel_buffer_b),
		create_storage_uniform(2, params_buffer), # Same params buffer
		create_storage_uniform(3, pos_buffer_a),
		create_storage_uniform(4, vel_buffer_a)
	]
	uniform_set_b = rd.uniform_set_create(uniforms_b, shader, 0)

	pipeline = rd.compute_pipeline_create(shader)

	if not boid_scene: printerr("Boid scene not set!"); return
	# Spawn boids and place them at their initial starting positions
	for i in range(boid_count):
		var new_boid : RigidBody3D = boid_scene.instantiate()
		if new_boid:
			add_child(new_boid)
			boids.push_back(new_boid)
			new_boid.position = Vector3(
				pos_start_arr[i*3], pos_start_arr[i*3+1], pos_start_arr[i*3+2]
			)
			new_boid.linear_velocity = Vector3(
				vel_start_arr[i*3], vel_start_arr[i*3+1], vel_start_arr[i*3+2]
			)
		else:
			printerr("Failed to instantiate boid scene")
	last_update_time = Time.get_ticks_msec()

func _process(delta):
	# Only update x times per second (see updates_per_second)
	var current_time = Time.get_ticks_msec() 
	var msec_since_update = current_time - last_update_time
	var sec_since_update = msec_since_update / 1000.0
	if sec_since_update < update_delay:
		return

	# Guard
	if not pipeline.is_valid(): return 

	# Update delta in params buffer (for potentially doing verlet integration)
	var delta_bytes = PackedByteArray()
	delta_bytes.resize(4)
	delta_bytes.encode_float(0, float(delta))
	rd.buffer_update(params_buffer, 4, 4, delta_bytes) # Offset 4 for delta

	# Run Compute shader
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

	# Bind the correct uniform set
	if current_set_is_a:
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_a, 0)
	else:
		rd.compute_list_bind_uniform_set(compute_list, uniform_set_b, 0)

	# Dispatch (group count based on local_size_x in shader)
	var work_group_size_x = 1 
	# var group_count = int(ceil(float(boid_count) / float(work_group_size_x)))
	var group_count = boid_count / work_group_size_x
	rd.compute_list_dispatch(compute_list, group_count, 1, 1)
	rd.compute_list_end()

	# Submit and Sync
	rd.submit()
	rd.sync() # Necessary to ensure compute finishes before reading

	# Update Visuals from the buffer that was just written to
	var read_pos_buffer 
	var read_vel_buffer
	var write_pos_buffer
	var write_vel_buffer
	if current_set_is_a:
		read_pos_buffer = pos_buffer_b
		read_vel_buffer = vel_buffer_b
		write_pos_buffer = pos_buffer_a
		write_vel_buffer = vel_buffer_a
	else:
		read_pos_buffer = pos_buffer_a
		read_vel_buffer = vel_buffer_a
		write_pos_buffer = pos_buffer_b
		write_vel_buffer = vel_buffer_b
	update_boids_position(read_pos_buffer, read_vel_buffer)
	update_gpu_buffers(write_pos_buffer, write_vel_buffer)

	# Swap for next frame
	current_set_is_a = not current_set_is_a
	print("Buffers swapped!")

	# Record the last time we updated
	last_update_time = Time.get_ticks_msec()

func update_boids_position(pos_buffer_read: RID, vel_buffer_read: RID):
	var pos_bytes = rd.buffer_get_data(pos_buffer_read)
	var vel_bytes = rd.buffer_get_data(vel_buffer_read)

	# Basic check, decode assumes valid data
	if pos_bytes.is_empty() or vel_bytes.is_empty(): return

	# Using PackedFloat32Array.to_float32_array() might be slightly less direct than decode_f32
	var pos_output = pos_bytes.to_float32_array()
	var vel_output = vel_bytes.to_float32_array()

	if pos_output.size() < boid_count * 3 or vel_output.size() < boid_count * 3:
		printerr("Buffer data size mismatch.")
		return

	for i in range(boid_count):
		if i >= boids.size(): break # Safety check

		var cur_boid = boids[i]
		var base_idx = i * 3
		var new_pos = Vector3(pos_output[base_idx + 0], pos_output[base_idx + 1], pos_output[base_idx + 2])
		var new_vel = Vector3(vel_output[base_idx + 0], vel_output[base_idx + 1], vel_output[base_idx + 2])

		# cur_boid.position = new_pos
		cur_boid.linear_velocity = new_vel

func update_gpu_buffers(write_pos_buffer, write_vel_buffer):
	var pos_arr = PackedFloat32Array()
	pos_arr.resize(boid_count * 3)
	var vel_arr = PackedFloat32Array()
	vel_arr.resize(boid_count * 3)
	for i in range(boid_count):
		var boid = boids[i]
		var boid_pos = boid.position
		var boid_vel = boid.linear_velocity
		pos_arr[i*3+0] = boid_pos.x
		pos_arr[i*3+1] = boid_pos.y
		pos_arr[i*3+2] = boid_pos.z
		vel_arr[i*3+0] = boid_vel.x
		vel_arr[i*3+1] = boid_vel.y
		vel_arr[i*3+2] = boid_vel.z

	var pos_bytes = pos_arr.to_byte_array()
	var vel_bytes = vel_arr.to_byte_array()	

	rd.buffer_update(write_pos_buffer, 0, pos_bytes.size(), pos_bytes)
	rd.buffer_update(write_vel_buffer, 0, vel_bytes.size(), vel_bytes)
