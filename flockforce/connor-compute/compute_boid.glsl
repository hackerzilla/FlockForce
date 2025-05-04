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

vec3 wrapVec3(vec3 v, vec3 a, vec3 b) {
    vec3 range = b - a;
    return a + mod(v - a, range);
}

// This is the buffer for int params (boid count only)
layout(set = 0, binding = 4, std430) restrict buffer Params{
    float boid_count;
    float current_buffer;
    float separation_strength;
    float alignment_strength;
    float cohesion_strength;
    float delta;
    float neighborhood_size;
    float avoid_size;
    float limit;
} params;


// const float neighborhood_size = 3.0;
// const float avoid_size = 2.0;

// const float separation_strength = 0.9;
// const float alignment_strength = 0.7;
// const float cohesion_strength = 0.9;

// const float limit = 30.0;


// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    // my_data_buffer.data[gl_GlobalInvocationID.x] *= 2.0;

    vec3 boid_read_position;
    vec3 boid_read_velocity;
    if (params.current_buffer == 0.0) {
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
    int total_boids = int(params.boid_count);

    for (int i = 0; i < total_boids; i++) {
        if (i == gl_GlobalInvocationID.x) {
            continue;
        }
        vec3 other_position;
        vec3 other_velocity;
        if (params.current_buffer == 0.0) {
            other_position = positions_a.data[i];
            other_velocity = velocities_a.data[i];
        } else {
            other_position = positions_b.data[i];
            other_velocity = velocities_b.data[i];
        }

        vec3 pos_difference = boid_read_position - other_position;
        if (length(pos_difference) > params.neighborhood_size) {
            continue;
        }
        avg_position += other_position;
        avg_velocity += other_velocity;
        num_neighbors += 1;

        if (length(pos_difference) > params.avoid_size) {
            continue;
        }
        avoid_vector += pos_difference;
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
    vec3 to_com = vec3(0.0);
    if (length(avg_position - boid_read_position) > 0.0) {
        to_com = normalize(avg_position - boid_read_position);
    }

    // vec3 separation = -to_com;
    vec3 separation = vec3(0.0);
    if (length(avoid_vector) > 0.0) {
        separation = normalize(avoid_vector);
    }
    vec3 cohesion = to_com;
    vec3 alignment = avg_velocity;

    boid_read_velocity = (separation * params.separation_strength) + (alignment * params.alignment_strength) + (cohesion * params.cohesion_strength);
    // boid_read_velocity = (separation * separation_strength);
    // boid_read_velocity = (cohesion * cohesion_strength);
    // boid_read_velocity = (alignment * alignment_strength);

    boid_read_velocity = normalize(boid_read_velocity);
    boid_read_position = boid_read_position + boid_read_velocity * params.delta * 5; // should this include something related to timesteps?

    // if (boid_read_position.x > limit) boid_read_position.x = -inside_limit;
    // if (boid_read_position.x < -limit) boid_read_position.x = inside_limit;
    // if (boid_read_position.y > limit) boid_read_position.y = -inside_limit;
    // if (boid_read_position.y < -limit) boid_read_position.y = inside_limit;
    // if (boid_read_position.z > limit) boid_read_position.z = -inside_limit;
    // if (boid_read_position.z < -limit) boid_read_position.z = inside_limit;



    // boid_read_position = clamp(boid_read_position, vec3(-params.limit), vec3(params.limit));

    boid_read_position = wrapVec3(boid_read_position, vec3(-params.limit), vec3(params.limit));

    if (params.current_buffer == 0.0) {
        positions_b.data[gl_GlobalInvocationID.x] = boid_read_position;
        velocities_b.data[gl_GlobalInvocationID.x] = boid_read_velocity;
    } else {
        positions_a.data[gl_GlobalInvocationID.x] = boid_read_position;
        velocities_a.data[gl_GlobalInvocationID.x] = boid_read_velocity;
    }
    

}

