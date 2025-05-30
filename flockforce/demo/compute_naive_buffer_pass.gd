extends Node
class_name ComputeBoids

@export
var boid_scene: PackedScene

@export 
var spawn_radius: float = 30.0

@export 
var separation: float = 1.0

@export 
var alignment: float = 0.8

@export 
var cohesion: float = 1.0

var boids: Array[RigidBody3D] = []

@export
var boid_count: int = 2000

@export 
var neighborhood_size: float = 3.0

@export 
var avoid_size: float = 2.0

@export
var limit: float = 30.0

# GUI stuff
var cohesion_slider     : HSlider
var separation_slider   : HSlider
var alignment_slider    : HSlider
var neighborhood_slider : HSlider
var avoidance_slider    : HSlider

# create a local rendering device
var rd := RenderingServer.create_local_rendering_device()

# Load GLSL shader
var shader_file := load("res://demo/compute_boid.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)

# Prepare our data. We use floats in the shader, so we need 32 bit.
var position
var position_bytes

var velocity 
var velocity_bytes

# Create a storage buffer that can hold our float values.
# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
var current_buffer = 0
var pos_buffer_a
var vol_buffer_a
var pos_buffer_b
var vol_buffer_b

var params_buffer

# Create a uniform to assign the buffer to the rendering device
var pos_uniform_a
var vol_uniform_a
var pos_uniform_b
var vol_uniform_b
var params_uniform

var uniform_set
var pipeline

#function to spawn boids and put data in inputBuffer

func _ready():
	# Initialize gui references
	cohesion_slider = get_tree().root.get_node("Demo/GUI/CohesionSlider")
	separation_slider = get_tree().root.get_node("Demo/GUI/SeparationSlider")
	alignment_slider = get_tree().root.get_node("Demo/GUI/AlignmentSlider")
	neighborhood_slider = get_tree().root.get_node("Demo/GUI/NeighborhoodSlider")
	avoidance_slider = get_tree().root.get_node("Demo/GUI/AvoidanceSlider")
	
	var rng = RandomNumberGenerator.new()
	var pos_start_arr = []
	var vol_start_arr = []
	for i in range(boid_count):
		for j in range(3):
			pos_start_arr.push_back(rng.randf_range(-spawn_radius, spawn_radius))
			#pos_start_arr.push_back(i * 0.2) exists for testing purposes
			vol_start_arr.push_back(rng.randf_range(-1, 1))
		pos_start_arr.push_back(0.0) #padding for vec3
		vol_start_arr.push_back(0.0) #padding for vec3
	position = PackedFloat32Array(pos_start_arr)
	position_bytes = position.to_byte_array()
	print("the position byte array is of size: ", position_bytes.size())

	velocity = PackedFloat32Array(vol_start_arr)
	velocity_bytes = velocity.to_byte_array()
	print("the velocity byte array is of size: ", velocity_bytes.size())


	# Create a storage buffer that can hold our float values.
	# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	pos_buffer_a = rd.storage_buffer_create(position_bytes.size(), position_bytes)
	vol_buffer_a = rd.storage_buffer_create(velocity_bytes.size(), velocity_bytes)
	pos_buffer_b = rd.storage_buffer_create(position_bytes.size(), position_bytes)
	vol_buffer_b = rd.storage_buffer_create(velocity_bytes.size(), velocity_bytes)
	
	var params_bytes  = PackedFloat32Array([boid_count, current_buffer, separation, alignment, cohesion, 0.0, neighborhood_size, avoid_size, limit]).to_byte_array()
	params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)

	# Create a uniform to assign the buffer to the rendering device
	pos_uniform_a = RDUniform.new()
	vol_uniform_a = RDUniform.new()
	pos_uniform_b = RDUniform.new()
	vol_uniform_b = RDUniform.new()
	params_uniform = RDUniform.new()
	initialize_boids()
	#print("ready called")
	pos_uniform_a.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform_a.binding = 0 # this needs to match the "binding" in our shader file
	pos_uniform_a.add_id(pos_buffer_a)
	
	vol_uniform_a.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vol_uniform_a.binding = 1 # this needs to match the "binding" in our shader file
	vol_uniform_a.add_id(vol_buffer_a)
	
	pos_uniform_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform_b.binding = 2 # this needs to match the "binding" in our shader file
	pos_uniform_b.add_id(pos_buffer_b)
	
	vol_uniform_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vol_uniform_b.binding = 3 # this needs to match the "binding" in our shader file
	vol_uniform_b.add_id(vol_buffer_b)
	
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 4 # this needs to match the "binding" in our shader file
	params_uniform.add_id(params_buffer)
	
	pipeline = rd.compute_pipeline_create(shader)
	uniform_set = rd.uniform_set_create([pos_uniform_a, vol_uniform_a, pos_uniform_b, vol_uniform_b, params_uniform], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file
	print(pipeline, uniform_set)
	


func _process(delta):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, boid_count / 2, 1, 1)
	rd.compute_list_end()
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	update_boids_position()
	if (current_buffer == 0):
		current_buffer = 1
	else:
		current_buffer = 0
	 
	var new_params_bytes = PackedFloat32Array([boid_count, current_buffer, separation, alignment, cohesion, delta, neighborhood_size, avoid_size, limit]).to_byte_array()
	rd.buffer_update(params_buffer, 0, new_params_bytes.size(), new_params_bytes)

	
	# Read back the data from the buffer
	
	#var output_bytes = rd.buffer_get_data(pos_buffer)
	##rd.buffer_update(buffer, 0, len(output_bytes), output_bytes)
	#var output = output_bytes.to_float32_array()
	#print("Output: ", output)

func update_boids_position():
	var pos_output_bytes
	var vol_output_bytes
	
	if current_buffer == 0:
		pos_output_bytes = rd.buffer_get_data(pos_buffer_a)
		vol_output_bytes = rd.buffer_get_data(vol_buffer_a)
	else:
		pos_output_bytes = rd.buffer_get_data(pos_buffer_b)
		vol_output_bytes = rd.buffer_get_data(vol_buffer_b)
	
	var pos_output = pos_output_bytes.to_float32_array()
	var vol_output = vol_output_bytes.to_float32_array()
	
	for i in range(len(boids)):
		#if (i < 3):
			#continue
		var cur_boid = boids[i]
		#var prev_pos = cur_boid.position
		var new_pos = Vector3(pos_output[(i*4)], pos_output[(i*4) + 1], pos_output[(i*4) + 2])
		#if (prev_pos - new_pos).length() > 1:
			#print("issue with boid: ", i, " distance of: ", (prev_pos - new_pos).length())
		#var new_pos = Vector3(0,0,0)
		var new_vol = Vector3(vol_output[(i*4)], vol_output[(i*4) + 1], vol_output[(i*4) + 2])
		if contains_nan(new_pos):
			print("new_pos contains NaN")
		if contains_nan(new_vol):
			print("new_vol contains NaN")
		cur_boid.position = new_pos		
		cur_boid.linear_velocity = new_vol
		
		if new_vol.length() > 0:
			var direction = new_vol.normalized()
			var up = Vector3.UP
			
			# Check if direction is colinear with up vector
			if abs(direction.dot(up)) > 0.999:
				# direction is almost parallel to up vector, choose another up vector
				up = Vector3.FORWARD
			
			var target_pos = cur_boid.global_transform.origin + new_vol
			cur_boid.look_at(target_pos, up)
			cur_boid.rotation.y -= 90
			cur_boid.rotation.x = 0

func contains_nan(vec):
	return (vec.x != vec.x) or (vec.y != vec.y) or (vec.z != vec.z)

		
func initialize_boids():
	for i in range(boid_count):
		var new_boid : RigidBody3D = boid_scene.instantiate()
		assert(new_boid != null, 
			"error in boid manager: the " + str(i) + "the boid is null!"
		)
		add_child(new_boid) # add to the scene tree
		boids.push_back(new_boid)
		#print("created boid")
		
		var anim_player = new_boid.get_node("AnimationPlayer")
		anim_player.play("ArmatureAction_006")
		var rng = RandomNumberGenerator.new()
		anim_player.seek(rng.randf() * 9.0, true)

# Signal callbacks from GUI objects
func _on_cohesion_slider_value_changed(value: float) -> void:
	if cohesion_slider != null:
		cohesion = value

func _on_separation_slider_value_changed(value: float) -> void:
	if separation_slider != null:
		separation = separation_slider.value

func _on_alignment_slider_value_changed(value: float) -> void:
	if alignment_slider != null:
		alignment = alignment_slider.value

func _on_neighborhood_slider_value_changed(value: float) -> void:
	if neighborhood_slider != null:
		neighborhood_size = value

func _on_avoidance_slider_value_changed(value: float) -> void:
	if avoidance_slider != null:
		avoid_size = value
