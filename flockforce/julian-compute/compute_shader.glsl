#[compute]
#version 450

// Invocations in the (x, y, z) dimension
// Compute Shader can process data in three dimensions. 
// This is essentially an efficient design intended for 1D, 2D, and 3D data structures.
// In our example, since we are processing a 1D array, we are only using the X axis.
//////////////////////////////////////////////////////////////////////////////////////////////// 
// Defining the axes we'll use on the GPU. Here, only the X axis. 2 threads on the X axis.
layout(local_size_x = 2, local_size_y = 1, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
// Connecting our data to the GPU.
// set = Data type
// binding = GPU binding point
// std430 = GPU memory structure standard.
// restrict buffer MyDataBuffer = Buffer with restricted access for optimization purposes.
layout(set = 0, binding = 0, std430) restrict buffer MyDataBuffer {
	float data[];
}
my_data_buffer;

// This code is executed in each invocation
void main() {
	// gl_GlobalInvocationID uniquely identifies this invocation across all work groups
	my_data_buffer.data[gl_GlobalInvocationID.x] *= 2.0;
}
