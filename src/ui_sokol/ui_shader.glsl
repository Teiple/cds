@header package ui_sokol
@header import sg "../sokol/gfx"
@ctype mat4 matrix[4,4]f32

@vs vs
layout(binding=0) uniform vs_params {
    mat4 ortho_proj;
};

in vec2 pos;
in vec2 uv0;
in vec4 color0;

out vec2 uv;
out vec4 color;

void main() {
    gl_Position = ortho_proj * vec4(pos, 0.0, 1.0);
    uv = uv0;
    color = color0;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec2 uv;
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), uv) * color;
}
@end

@program ui vs fs

