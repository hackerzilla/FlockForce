#[compute]
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// Input Buffers (Read)
layout(set = 0, binding = 0, std430) readonly buffer PositionIn {
    vec3 data[];
} positions_in;

layout(set = 0, binding = 1, std430) readonly buffer VelocityIn {
    vec3 data[];
} velocities_in;

// Parameters (Only count and delta)
layout(set = 0, binding = 2, std430) readonly buffer Params{
    int boid_count;
    float delta; // Keep delta time
} params;

// Output Buffers (Write)
layout(set = 0, binding = 3, std430) writeonly buffer PositionOut {
    vec3 data[];
} positions_out;

layout(set = 0, binding = 4, std430) writeonly buffer VelocityOut {
    vec3 data[];
} velocities_out;

// Constants moved back into shader
const float neighborhood_size = 30.0;
const float separation_strength = 0.5;
const float alignment_strength = 1.0;
const float cohesion_strength = 1.2;
const float max_speed = 15.0; // Example max speed
const float MIN_SPEED = 0.1; // Prevent complete stopping if desired
const float EPSILON = 0.0001; // Small value to prevent division by zero / normalize zero vector

// Safe normalize function
vec3 safe_normalize(vec3 v) {
    float len = length(v);
    if (len < EPSILON) {
        return vec3(0.0); // Return zero vector if length is too small
    }
    return v / len;
}

void main() {
    uint index = gl_GlobalInvocationID.x;
    int total_boids = params.boid_count;

    if (index >= total_boids) {
        return;
    }

    // Testing data passthrough
    positions_out.data[index] = positions_in.data[index];
    velocities_out.data[index] = velocities_in.data[index];
    return;

    // Read from input buffers
    vec3 boid_position = positions_in.data[index];
    vec3 boid_velocity = velocities_in.data[index];

    vec3 avg_position = vec3(0.0);
    vec3 avg_velocity = vec3(0.0);
    vec3 separation_force = vec3(0.0);
    int num_neighbors = 0;

    // Calculate neighbors (reading from input buffers)
    for (int i = 0; i < total_boids; i++) {
        if (i == index) continue;

        vec3 other_position = positions_in.data[i];
        vec3 pos_difference = other_position - boid_position;
        float dist_sq = dot(pos_difference, pos_difference);

        if (dist_sq > EPSILON && dist_sq < (neighborhood_size * neighborhood_size)) {
            avg_position += other_position;
            avg_velocity += velocities_in.data[i]; // Read neighbor velocity

            // Separation: Use distance squared and add epsilon to denominator for safety
            // Force is stronger when closer. Avoid sqrt if possible.
            // Using 1/dist_sq falloff might be more stable than 1/dist
            separation_force -= pos_difference / (dist_sq + EPSILON); // Added epsilon

            num_neighbors++;
        }
    }

    vec3 final_velocity = boid_velocity;
    vec3 acceleration = vec3(0.0);

    if (num_neighbors > 0) {
        // Cohesion
        avg_position /= num_neighbors;
        vec3 cohesion_vector = avg_position - boid_position;
        vec3 cohesion_force = safe_normalize(cohesion_vector); // Use safe normalize

        // Alignment
        avg_velocity /= num_neighbors;
        vec3 alignment_force = safe_normalize(avg_velocity);

        // Separation
        // separation_force was accumulated, normalize it safely
        // We might divide by num_neighbors here as well if using 1/dist instead of 1/dist^2
        separation_force = safe_normalize(separation_force);
    }
    // else: If no neighbours, acceleration remains (0,0,0)

    // --- Apply Acceleration ---
    // Ensure delta is reasonable (should be handled in GDScript, but clamp here just in case)
    float safe_delta = clamp(params.delta, 0.0, 0.1); // Clamp delta to avoid explosions
    final_velocity += acceleration * safe_delta;


    // Limit speed
    float speed = length(final_velocity);
    if (speed > max_speed) {
        final_velocity = safe_normalize(final_velocity) * max_speed;
    } else if (speed < MIN_SPEED) {
        // Optional: prevent stopping completely or drifting too slow
        // Give it a nudge in its current direction if it's moving, or a default direction
         if (speed > EPSILON) { // Only normalize if it wasn't already near zero
              final_velocity = safe_normalize(final_velocity) * MIN_SPEED;
         } else {
             // Optional: Assign a default small velocity if completely stopped
             // final_velocity = vec3(MIN_SPEED, 0.0, 0.0); // Or based on index?
         }
    }

    // Update position
    vec3 next_position = boid_position + final_velocity * safe_delta;

    // --- Final Sanity Check (Optional but can help debugging) ---
    // if (!all(isfinite(next_position)) || !all(isfinite(final_velocity))) {
    //     // Handle error state - e.g., reset to origin or keep old values
    //     next_position = vec3(0.0); // Or boid_position
    //     final_velocity = vec3(0.0); // Or boid_velocity
    // }

    // --- Write to Output Buffers ---
    positions_out.data[index] = next_position;
    velocities_out.data[index] = final_velocity;
}