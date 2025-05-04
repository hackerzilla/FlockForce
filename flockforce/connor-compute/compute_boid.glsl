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


const float neighborhood_size = 1.2;
const float avoid_size = 1.0;

const float separation_strength = 0.9;
const float alignment_strength = 0.6;
const float cohesion_strength = 0.9;

const float limit = 15.0;


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
    
    vec3 avg_position = vec3(0.0);
    vec3 avg_velocity = vec3(0.0);
    vec3 avoid_vector = vec3(0.0);
    int num_neighbors = 0;
    int num_avoids = 0;
    int total_boids = params.boid_count;

    for (int i = 0; i < total_boids; i++) {
        if (i == gl_GlobalInvocationID.x) {
            continue;
        }
        vec3 other_position;
        vec3 other_velocity;
        if (params.current_buffer == 0) {
            other_position = positions_a.data[i];
            other_velocity = velocities_a.data[i];
        } else {
            other_position = positions_b.data[i];
            other_velocity = velocities_b.data[i];
        }

        vec3 pos_difference = boid_read_position - other_position;
        if (any(isinf(pos_difference)) || any(isnan(pos_difference))) continue;
        if (length(pos_difference) > neighborhood_size) {
            continue;
        }
        avg_position += other_position;
        avg_velocity += other_velocity;
        num_neighbors += 1;

        if (length(pos_difference) > avoid_size) {
            continue;
        }
        avoid_vector += normalize(pos_difference);
        num_avoids += 1;
    }
    if (num_neighbors !=0) {
        avg_position /= num_neighbors;
        avg_velocity /= num_neighbors;
    } else {
        avg_position = boid_read_position;
        avg_velocity = boid_read_velocity;
    }
    if (num_avoids != 0) {
        avoid_vector /= num_avoids;
    }
    vec3 to_com = normalize(avg_position - boid_read_position);
    // vec3 separation = -to_com;
    vec3 separation = avoid_vector;
    vec3 cohesion = to_com;
    vec3 alignment = avg_velocity;

    boid_read_velocity = (separation * separation_strength) + (alignment * alignment_strength) + (cohesion * cohesion_strength);
    boid_read_velocity = normalize(boid_read_velocity);
    boid_read_position = boid_read_position + boid_read_velocity * 0.05; // should this include something related to timesteps?

    boid_read_position = clamp(boid_read_position, vec3(-limit), vec3(limit));

    if (params.current_buffer == 0) {
        positions_b.data[gl_GlobalInvocationID.x] = boid_read_position;
        velocities_b.data[gl_GlobalInvocationID.x] = boid_read_velocity;
    } else {
        positions_a.data[gl_GlobalInvocationID.x] = boid_read_position;
        velocities_a.data[gl_GlobalInvocationID.x] = boid_read_velocity;
    }
}