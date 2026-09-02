// Note: SDF by Iñigo Quilez is licensed under MIT License

#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
// in vec4 fragColor;

// Input uniform values
// uniform sampler2D texture0;
// uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

uniform vec4 rectangle; // Rectangle dimensions (x, y, width, height)
uniform vec4 radius; // Corner radius (top-left, top-right, bottom-left, bottom-right)
uniform vec4 color;

// Shadow parameters
uniform int shadowEnabled;
uniform float shadowRadius;
uniform vec2 shadowOffset;
uniform vec4 shadowColor;

// Border parameters
uniform float borderThickness;
uniform vec4 borderColor;

// Masking
uniform vec4 maskRectangle;

float sdRoundRect(vec2 p, vec2 halfSize, vec4 radius) {

    // Determine which corner radius to use
    radius.xy = (p.y > 0.0) ? radius.xy : radius.zw;
    radius.x = (p.x < 0.0) ? radius.x : radius.y;

    // Calculate signed distance field
    vec2 dist = abs(p) - halfSize + radius.x;
    return min(max(dist.x, dist.y), 0.0) + length(max(dist, 0.0)) - radius.x;
}

bool inRect(vec2 p, vec2 pos, vec2 size) {
    return p.x >= pos.x && p.x <= pos.x + size.x && p.y >= pos.y && p.y <= pos.y + size.y;
}

vec4 compositeOver(vec4 under, vec4 over) {
    float outA = over.a + under.a * (1.0 - over.a);

    if(outA <= 0.0)
        return vec4(0.0);

    vec3 outRGB = (over.rgb * over.a +
        under.rgb * under.a * (1.0 - over.a)) / outA;

    return vec4(outRGB, outA);
}

void main() {
    // Texel color fetching from texture sampler
    // vec4 texelColor = texture(texture0, fragTexCoord);

    // Requires fragment coordinate in pixels
    vec2 fragCoord = gl_FragCoord.xy;

    if(maskRectangle.z > 0 && maskRectangle.w > 0 && !inRect(fragCoord, maskRectangle.xy, maskRectangle.zw)) {
        discard;
    }

    // Calculate signed distance field for rounded rectangle
    vec2 halfSize = rectangle.zw * 0.5;
    vec2 center = rectangle.xy + halfSize;
    float recSdf = sdRoundRect(fragCoord - center, halfSize, radius);

    // Calculate signed distance field for rectangle shadow

    // Anti-aliasing
    float aa = max(fwidth(recSdf) * 0.5, 0.001);

    // Calculate alpha factors
    float recFactor = 1.0 - smoothstep(-borderThickness - aa, -borderThickness + aa, recSdf);
    float outerFactor = 1.0 - smoothstep(-aa, aa, recSdf); // Outer rounded-rect coverage
    float borderFactor = max(outerFactor - recFactor, 0.0); // The region between the two edges is the border

    // Multiply each color by its respective alpha factor
    vec4 recColor = vec4(color.rgb, color.a * recFactor);
    vec4 borderCol = vec4(borderColor.rgb, borderColor.a * borderFactor);
    vec4 shadowCol;
    vec4 result;

    if(shadowEnabled != 0) {
        // Shadows
        vec2 shadowCenter = center + shadowOffset;
        float shadowSdf = sdRoundRect(fragCoord - shadowCenter, halfSize, radius);
        float shadowFactor = smoothstep(shadowRadius, 0.0, shadowSdf);

        shadowCol = vec4(shadowColor.rgb, shadowColor.a * shadowFactor);

        // Combine the colors in the order (shadow, rectangle, border)
        result = compositeOver(compositeOver(shadowCol, recColor), borderCol);
    } else {
        // Rec + Border only
        result = compositeOver(recColor, borderCol);
    }

    finalColor = result;
}
