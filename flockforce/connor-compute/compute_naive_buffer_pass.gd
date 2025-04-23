extends Node	

@export
var boid_scene: PackedScene

var boids: Array[RigidBody3D] = []

var boid_count = 3

# create a local rendering device
var rd := RenderingServer.create_local_rendering_device()

# Load GLSL shader
var shader_file := load("res://connor-compute/compute_boid.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)

# Prepare our data. We use floats in the shader, so we need 32 bit.
var position := PackedFloat32Array([1, 2, 3, 4, 5, 6, 7, 8, 9])
var position_bytes := position.to_byte_array()

var velocity := PackedFloat32Array([0, 0.4, 0, 0, 0.5, 0, 0, 0.6, 0])
var velocity_bytes = velocity.to_byte_array()

# Create a storage buffer that can hold our float values.
# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
var pos_buffer := rd.storage_buffer_create(position_bytes.size(), position_bytes)

var vol_buffer := rd.storage_buffer_create(velocity_bytes.size(), velocity_bytes)

# Create a uniform to assign the buffer to the rendering device
var pos_uniform := RDUniform.new()
var vol_uniform := RDUniform.new()

#function to spawn boids and put data in inputBuffer

func _ready():
	initialize_boids()
	print("ready called")
	pos_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	pos_uniform.binding = 0 # this needs to match the "binding" in our shader file
	pos_uniform.add_id(pos_buffer)
	
	vol_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vol_uniform.binding = 1 # this needs to match the "binding" in our shader file
	vol_uniform.add_id(vol_buffer)
	
	


func _process(delta):
	var uniform_set := rd.uniform_set_create([pos_uniform, vol_uniform], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	update_boids_position()
	
	
	# Read back the data from the buffer
	
	#var output_bytes = rd.buffer_get_data(pos_buffer)
	##rd.buffer_update(buffer, 0, len(output_bytes), output_bytes)
	#var output = output_bytes.to_float32_array()
	#print("Output: ", output)


func update_boids_position():
	var pos_output_bytes = rd.buffer_get_data(pos_buffer)
	var pos_output = pos_output_bytes.to_float32_array()
	
	var vol_output_bytes = rd.buffer_get_data(vol_buffer)
	var vol_output = vol_output_bytes.to_float32_array()
	
	for i in range(len(boids)):
		var cur_boid = boids[i]
		var new_pos = Vector3(pos_output[(i*3)], pos_output[(i*3) + 1], pos_output[(i*3) + 2])
		#var new_pos = Vector3(0,0,0)
		var new_vol = Vector3(vol_output[(i*3)], vol_output[(i*3) + 1], vol_output[(i*3) + 2])
		cur_boid.position = new_pos
		cur_boid.linear_velocity = new_vol
		
func initialize_boids():
	for i in range(boid_count):
		var new_boid : RigidBody3D = boid_scene.instantiate()
		assert(new_boid != null, 
			"error in boid manager: the " + str(i) + "th boid is null!"
		)
		add_child(new_boid) # add to the scene tree
		boids.push_back(new_boid)
		print("created boid")
