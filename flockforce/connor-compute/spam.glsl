const float neighborhood_size = 3.0;
const float avoid_size = 2.0;

const float separation_strength = 0.9;
const float alignment_strength = 0.7;
const float cohesion_strength = 0.9;

const float limit = 15.0;

void main() {
    uint id = gl_GlobalInvocationID.x;

    vec3 boid_read_position;
    vec3 boid_read_velocity;
    if (params.current_buffer == 0) {
        boid_read_position = positions_a.data[id];
        boid_read_velocity = velocities_a.data[id];
    } else {
        boid_read_position = positions_b.data[id];
        boid_read_velocity = velocities_b.data[id];
    }

    // Early exit if this boid has invalid position/velocity
    if (!all(isfinite(boid_read_position)) || !all(isfinite(boid_read_velocity))) {
        return;
    }

    vec3 avg_position = vec3(0.0);
    vec3 avg_velocity = vec3(0.0);
    vec3 avoid_vector = vec3(0.0);
    int num_neighbors = 0;
    int num_avoids = 0;
    int total_boids = params.boid_count;

    for (int i = 0; i < total_boids; i++) {
        if (i == id) continue;

        vec3 other_position;
        vec3 other_velocity;
        if (params.current_buffer == 0) {
            other_position = positions_a.data[i];
            other_velocity = velocities_a.data[i];
        } else {
            other_position = positions_b.data[i];
            other_velocity = velocities_b.data[i];
        }

        if (!all(isfinite(other_position)) || !all(isfinite(other_velocity))) {
            continue; // Skip invalid neighbors
        }

        vec3 pos_difference = boid_read_position - other_position;
        float dist = length(pos_difference);

        if (!isfinite(dist)) continue;

        if (dist > neighborhood_size) continue;

        avg_position += other_position;
        avg_velocity += other_velocity;
        num_neighbors += 1;

        if (dist < avoid_size) {
            avoid_vector += normalize(pos_difference); // direction only
            num_avoids += 1;
        }
    }

    // Avoid division by zero and normalize safely
    if (num_neighbors > 0) {
        avg_position /= float(num_neighbors);
        avg_velocity /= float(num_neighbors);
    } else {
        avg_position = boid_read_position;
        avg_velocity = boid_read_velocity;
    }

    vec3 separation = vec3(0.0);
    if (num_avoids > 0) {
        separation = normalize(avoid_vector / float(num_avoids));
    }

    vec3 to_com = avg_position - boid_read_position;
    vec3 cohesion = length(to_com) > 0.001 ? normalize(to_com) : vec3(0.0);
    vec3 alignment = normalize(avg_velocity);

    boid_read_velocity = 
        (separation * separation_strength) +
        (alignment * alignment_strength) +
        (cohesion * cohesion_strength);

    if (length(boid_read_velocity) > 0.0001) {
        boid_read_velocity = normalize(boid_read_velocity);
    } else {
        boid_read_velocity = vec3(0.0);
    }

    boid_read_position += boid_read_velocity * 0.1;

    // Constrain to world bounds and ensure finite result
    boid_read_position = clamp(boid_read_position, vec3(-limit), vec3(limit));

    if (!all(isfinite(boid_read_position)) || !all(isfinite(boid_read_velocity))) {
        // Optionally: discard or reset this boid
        boid_read_position = vec3(0.0);
        boid_read_velocity = vec3(0.0);
    }

    // Write to output buffers
    if (params.current_buffer == 0) {
        positions_b.data[id] = boid_read_position;
        velocities_b.data[id] = boid_read_velocity;
    } else {
        positions_a.data[id] = boid_read_position;
        velocities_a.data[id] = boid_read_velocity;
    }
}
