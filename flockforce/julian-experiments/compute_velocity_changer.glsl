#[compute]
#version 450

// Dispatch groups
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer VelocityIn {
    vec3 data[];
} velocity_in;

layout(set = 0, binding = 1, std430) writeonly buffer VelocityOut {
    vec3 data[];
} velocity_out;

/* Math 3D Transformations */

const mat4 projection = mat4(
    vec4(3.0 / 4.0, 0.0, 0.0, 0.0),
    vec4(     0.0, 1.0, 0.0, 0.0),
    vec4(     0.0, 0.0, 0.5, 0.5),
    vec4(     0.0, 0.0, 0.0, 1.0)
);

mat4 scale = mat4(
    vec4(4.0 / 3.0, 0.0, 0.0, 0.0),
    vec4(     0.0, 1.0, 0.0, 0.0),
    vec4(     0.0, 0.0, 1.0, 0.0),
    vec4(     0.0, 0.0, 0.0, 1.0)
);

mat4 rotationAxis(float angle, vec3 axis) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

vec3 rotateX(vec3 p, float angle) {
    mat4 rmy = rotationAxis(angle, vec3(1.0, 0.0, 0.0));
    return (vec4(p, 1.0) * rmy).xyz;
}

vec3 rotateY_(vec3 p, float angle) {
    mat4 rmy = rotationAxis(angle, vec3(0.0, 1.0, 0.0));
    return (vec4(p, 1.0) * rmy).xyz;
}

vec3 rotateZ(vec3 p, float angle) {
    mat4 rmy = rotationAxis(angle, vec3(0.0, 0.0, 1.0));
    return (vec4(p, 1.0) * rmy).xyz;
}

vec3 rotateY(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    mat4 r = mat4(
        vec4(c, 0, s, 0),
        vec4(0, 1, 0, 0),
        vec4(-s, 0, c, 0),
        vec4(0, 0, 0, 1)
    );
    return (vec4(p, 1.0) * r).xyz;
}
void main() {
    // vec3 rotated_velocity = rotateZ(velocity_buffer.data[0], radians(15.0));
    // velocity_buffer.data[0] = velocity_buffer.data[0] - vec3(0, 0.2, 0);
    // velocity_buffer.data[0] = velocity_buffer.data[0];
    // velocity_buffer.data[0] = rotated_velocity;
    velocity_out.data[0] = velocity_in.data[0];
}