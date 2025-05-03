#[compute]
#version 450


// Invocations in the (x, y, z) dimension
layout(local_size_x = 2, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer Position_a {
    vec3 data[];
}
positions_a;

layout(set = 0, binding = 1, std430) restrict buffer Velocity_a {
    vec3 data[];
}
velocities_a;
layout(set = 0, binding = 2, std430) restrict buffer Position_b {
    vec3 data[];
}
positions_b;

layout(set = 0, binding = 3, std430) restrict buffer Velocity_b {
    vec3 data[];
}
velocities_b;


// This is the buffer for int params (boid count only)
layout(set = 0, binding = 4, std430) restrict buffer Params{
    int boid_count;
    int current_buffer;
} params;


const float neighborhood_size = 50.0;

const float separation_strength = 1.1;
const float alignment_strength = 1.0;
const float cohesion_strength = 1.0;


// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    // my_data_buffer.data[gl_GlobalInvocationID.x] *= 2.0;

    vec3 boid_read_position;
    vec3 boid_read_velocity;
    if (params.current_buffer == 0) {
        boid_read_position = positions_a.data[gl_GlobalInvocationID.x];
        boid_read_velocity = velocities_a.data[gl_GlobalInvocationID.x];
    } else {
        boid_read_position = positions_b.data[gl_GlobalInvocationID.x];
        boid_read_velocity = velocities_b.data[gl_GlobalInvocationID.x];
    }
    
    vec3 random_vec = vec3(0.0, 0.01, 0.0);
    boid_read_position = boid_read_position + random_vec;

    if (params.current_buffer == 0) {
        positions_b.data[gl_GlobalInvocationID.x] = boid_read_position;
        velocities_b.data[gl_GlobalInvocationID.x] = boid_read_velocity;
    } else {
        positions_a.data[gl_GlobalInvocationID.x] = boid_read_position;
        velocities_a.data[gl_GlobalInvocationID.x] = boid_read_velocity;
    }
    

}