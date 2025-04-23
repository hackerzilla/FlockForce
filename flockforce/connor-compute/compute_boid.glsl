#[compute]
#version 450


// Invocations in the (x, y, z) dimension
layout(local_size_x = 2, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec3 data[];
}
positions;

layout(set = 0, binding = 1, std430) restrict buffer Velocity {
    vec3 data[];
}
velocities;

const float neighborhood_size = 20.0;

const float separation_strength = 1.0;
const float alignment_strength = 1.0;
const float cohesion_strength = 1.0;


// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    // my_data_buffer.data[gl_GlobalInvocationID.x] *= 2.0;

    vec3 boid_position = positions.data[gl_GlobalInvocationID.x];
    vec3 boid_velocity = velocities.data[gl_GlobalInvocationID.x];
    vec3 avg_position = vec3(0.0);
    vec3 avg_velocity = vec3(0.0);
    int num_neighbors = 0;
    int total_boids = 3; //TODO

    for (int i = 0; i < total_boids; i++) {
        if (i == gl_GlobalInvocationID.x) {
            continue;
        }
        vec3 other_position = positions.data[i];
        vec3 other_velocity = velocities.data[i];
        vec3 pos_difference = boid_position - other_position;
        if (length(pos_difference) > neighborhood_size) {
            continue;
        }
        avg_position += other_position;
        avg_velocity += other_velocity;
        num_neighbors += 1;
    }
    if (num_neighbors !=0) {
        avg_position /= num_neighbors;
        avg_velocity /= num_neighbors;
    } else {
        avg_position = boid_position;
        avg_velocity = boid_velocity;
    }
    vec3 to_com = normalize(avg_position - boid_position);
    vec3 separation = -to_com;
    vec3 cohesion = to_com;
    vec3 alignment = avg_velocity;

    boid_velocity = (separation * separation_strength) + (alignment * alignment_strength) + (cohesion * cohesion_strength);
    boid_position = boid_position + boid_velocity; // should this include something related to timesteps?

    positions.data[gl_GlobalInvocationID.x] = boid_position;
    velocities.data[gl_GlobalInvocationID.x] = boid_velocity;

}