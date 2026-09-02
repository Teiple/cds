// source: https://github.com/raysan5/raylib/blob/master/examples/text/resources/shaders/glsl330/sdf.fs
#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// Masking
uniform vec4 maskRectangle;

// NOTE: Add your custom variables here

bool inRect(vec2 p, vec2 pos, vec2 size) {
    return p.x >= pos.x && p.x <= pos.x + size.x && p.y >= pos.y && p.y <= pos.y + size.y;
}

void main() {
    // Requires fragment coordinate in pixels
    if(maskRectangle.z > 0 && maskRectangle.w > 0 && !inRect(gl_FragCoord.xy, maskRectangle.xy, maskRectangle.zw)) {
        discard;
    }

    // Texel color fetching from texture sampler
    // NOTE: Calculate alpha using signed distance field (SDF)
    float distanceFromOutline = texture(texture0, fragTexCoord).a - 0.5;
    float distanceChangePerFragment = length(vec2(dFdx(distanceFromOutline), dFdy(distanceFromOutline)));
    float alpha = smoothstep(-distanceChangePerFragment, distanceChangePerFragment, distanceFromOutline);

    // Calculate final fragment color
    finalColor = vec4(fragColor.rgb, fragColor.a * alpha);
}