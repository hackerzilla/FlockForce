#[compute]
#version 450

// Dispatch groups
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer ColorBuffer {
    vec3 data[];
} color_buffer;

void main() {
    float red = color_buffer.data[0][0];
    red += 0.1;
    if (red > 1.0) {
        red = 0.0;
    }
    color_buffer.data[0][0] = red;
}