#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec4 maskRectangle;
uniform sampler2D texture0;

out vec4 finalColor;

bool inRect(vec2 p, vec2 pos, vec2 size) {
    return p.x >= pos.x && p.x <= pos.x + size.x &&
        p.y >= pos.y && p.y <= pos.y + size.y;
}

void main() {
    if(maskRectangle.z > 0.0 && maskRectangle.w > 0.0 &&
        !inRect(gl_FragCoord.xy, maskRectangle.xy, maskRectangle.zw)) {
        discard;
    }
    finalColor = texture(texture0, fragTexCoord) * fragColor;
}