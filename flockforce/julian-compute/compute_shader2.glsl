#[compute]
#version 450

// Invocations in the (x, y, z) dimension
// Compute Shader can process data in three dimensions. 
// This is essentially an efficient design intended for 1D, 2D, and 3D data structures.
// In our example, since we are processing a 1D array, we are only using the X axis.
//////////////////////////////////////////////////////////////////////////////////////////////// 
// Defining the axes we'll use on the GPU. Here, only the X axis. 2 threads on the X axis.
// the dimension 100 here is indicating 100 boids
layout(local_size_x = 100, local_size_y = 1, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
// Connecting our data to the GPU.
// set = Data type
// binding = GPU binding point
// std430 = GPU memory structure standard.
// restrict buffer MyDataBuffer = Buffer with restricted access for optimization purposes.
layout(set = 0, binding = 0, std430) restrict buffer MyDataBuffer {
	vec3 boid_positions[];
	vec3 boid_velocities[];
}
my_data_buffer;

const float cohesion_strength = 1.0;
const float alignment_strength = 1.0;
const float separation_strength = 1.0;

// This code is executed in each invocation
void main() {
	// gl_GlobalInvocationID uniquely identifies this invocation across all work groups
	// TODO: put boids algorithm here
	vec3 position = my_data_buffer.boid_positions[gl_GlobalInvocationID.x];
	// this should calculate the velocity for one boid, determined by the index gl_GlobalInvocationID.x
	// TODO: find all boids in neighborhood and get center of mass and average velocity
	vec3 neighbors_centroid = vec3(0);	
	vec3 average_velocity = vec3(0);
	// TODO: calculate cohesion, alignment, separation 
	vec3 cohesion = neighbors_centroid - position;
	vec3 alignment;
	vec3 separation = -cohesion;
	vec3 new_velocity = 
		cohesion * cohesion_strength + 
		alignment * alignment_strength +
		separation * separation_strength;
	// TODO: compute velocity sum and put in the buffer
	
	my_data_buffer.boid_velocities[gl_GlobalInvocationID.x] = new_velocity;
}
