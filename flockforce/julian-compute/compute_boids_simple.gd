extends Node3D

# Threads
var thread : Thread

# Compute shader pipeline
var rd           : RenderingDevice
var shader_path  := "res://julian-compute/compute_shader2.glsl"
var shader_file  : Resource
var shader_spirv : RDShaderSPIRV
var shader       : RID
var input        : PackedVector3Array
var input_bytes  : PackedByteArray
var buffer       : RID
var uniform      : RDUniform
var uniform_set  : RID
var pipeline     : RID
var compute_list : int
var output_bytes : PackedByteArray
var output_intermediary : PackedFloat32Array
var output       : PackedVector3Array

func float32_to_vector3_array(input: PackedFloat32Array) -> PackedVector3Array:
	assert(input.size() % 3 == 0, "input array should be divisible by 3 (it has vec3s right?)")
	var temp_arr : Array[Vector3] = []
	var temp_vec : Vector3
	for i in range(0, input.size()):

	var ouput: PackedVector3Array = PackedVector3Array(temp_arr)
	return output

func _ready() -> void:
	# initialize the dispatch thread
	thread = Thread.new()
	thread.start(initialize_thread)
	
	# Create a local rendering device...
	rd = RenderingServer.create_local_rendering_device()

	# Load the shader!
	shader_file = load(shader_path)
	shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

	# Shader uses 32 bit floats
	input = PackedVector3Array([Vector3(1, 2, 3)])

	input_bytes = input.to_byte_array()

	# Create a storage buffer on the device, get the ID
	buffer = rd.storage_buffer_create(input_bytes.size(), input_bytes)

	# Create a uniform to assign the buffer to the rendering device
	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the binding in our shader file
	uniform.add_id(buffer)
	uniform_set = rd.uniform_set_create([uniform], shader, 0)

	pipeline = rd.compute_pipeline_create(shader)
	compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	output_bytes = rd.buffer_get_data(buffer)
	output_intermediary = output_bytes.to_float32_array()
	output
	print("Input: ", input)
	print("Output: ", output)

	rd.free_rid(buffer)
	rd.free_rid(uniform_set)
	rd.free_rid(pipeline)

func _physics_process(delta: float) -> void:
	# idea: use compute shaders just to compute new velocities, set the velocities
		# on the CPU based on GPU returned result
	# at the start of program do:
		# compile compute shader
	# in a separate thread infinitely loop and do: 
		# fill a buffer with the positions of all boids
		# fill a buffer with the velocities of all boids
		# send the buffers to GPU along with compute shader pipeline
		# wait for result from GPU 
		# update velocities from the buffer
		# goto loop
	
	pass

func initialize_thread() -> void:
	print("thread working!")

func dispatch_compute_pipeline() -> void:
	
	pass
