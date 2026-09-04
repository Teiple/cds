#version 330

// ---- Inputs from vertex shader ----
in vec2 fragTexCoord;
in vec4 fragColor;          // Tint color from UI

// ---- Uniforms ----
uniform int mode;           // 0 = Rounded Rect, 1 = Text SDF

// ---- Clipping (same for both modes) ----
uniform vec4 maskRectangle; // x, y, width, height (bottom-left origin, screen coords)

// ---- Rect-specific uniforms ----
uniform vec4 rectPosSize;   // x, y, w, h (bottom-left origin, screen coords)
uniform vec4 rectColor;
uniform vec4 rectRadius;    // x=top-left, y=top-right, z=bottom-right, w=bottom-left
uniform vec4 borderColor;
uniform float borderThickness;
uniform int shadowEnabled;
uniform float shadowRadius;
uniform vec2 shadowOffset;
uniform vec4 shadowColor;

// ---- Text-specific uniforms ----
uniform sampler2D texture0; // Font atlas
// (colDiffuse is ignored; we use fragColor for tint)

// ---- Output ----
out vec4 finalColor;

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

// Check if a point is inside a rectangle
bool inRect(vec2 p, vec2 pos, vec2 size) {
    return p.x >= pos.x && p.x <= pos.x + size.x &&
        p.y >= pos.y && p.y <= pos.y + size.y;
}

// Signed Distance Field for a rounded rectangle.
// p : point relative to center (center is (0,0))
// b : half-size of the rectangle (width/2, height/2)
// r : corner radii (x=TL, y=TR, z=BR, w=BL)
float sdRoundRect(vec2 p, vec2 b, vec4 r) {
    // Select the correct radius for each quadrant
    r.xy = (p.x > 0.0) ? r.xy : r.xw;
    r.xy = (p.y > 0.0) ? r.xy : r.zy;
    vec2 q = abs(p) - b + r.xy;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0));
}

// Alpha compositing (source over destination)
vec4 compositeOver(vec4 src, vec4 dst) {
    return src + dst * (1.0 - src.a);
}

// ------------------------------------------------------------
// Main
// ------------------------------------------------------------
void main() {
    if(mode == 0) {
        finalColor = vec4(1.0, 0.0, 0.0, 1.0); // Red for rectangles
    } else if(mode == 1) {
        finalColor = vec4(0.0, 0.0, 1.0, 1.0); // Blue for text
    } else {
        finalColor = vec4(1.0, 1.0, 0.0, 1.0); // Yellow if mode is something else
    }
    // // ---- 1. Clipping (applies to both modes) ----
    // if(maskRectangle.z > 0.0 && maskRectangle.w > 0.0 &&
    //     !inRect(gl_FragCoord.xy, maskRectangle.xy, maskRectangle.zw)) {
    //     discard;
    // }

    // // ---- 2. Mode selection ----
    // if(mode == 0) {
    //     // ========== ROUNDED RECTANGLE PATH ==========
    //     vec2 pos = rectPosSize.xy;
    //     vec2 size = rectPosSize.zw;

    //     // Convert fragment coords to local space (centered at rect center)
    //     vec2 p = gl_FragCoord.xy - pos - size * 0.5;
    //     vec2 halfSize = size * 0.5;

    //     // Main rect SDF
    //     float mainSdf = sdRoundRect(p, halfSize, rectRadius);
    //     float aa = max(fwidth(mainSdf) * 0.5, 0.001);
    //     float alpha = 1.0 - smoothstep(-aa, aa, mainSdf);

    //     // vec4 color = rectColor;
    //     vec4 color = vec4(1.0, 0.0, 0.0, 1.0);

    //     // ---- Border ----
    //     if(borderThickness > 0.0) {
    //         vec2 innerHalf = halfSize - borderThickness;
    //         vec4 innerRadius = max(rectRadius - borderThickness, 0.0);
    //         float borderSdf = sdRoundRect(p, innerHalf, innerRadius);
    //         float borderAlpha = 1.0 - smoothstep(-aa, aa, borderSdf);
    //         color = mix(borderColor, color, borderAlpha);
    //     }

    //     // ---- Shadow ----
    //     if(shadowEnabled == 1) {
    //         // Move the SDF evaluation by the shadow offset
    //         vec2 shadowP = p - shadowOffset;
    //         float shadowSdf = sdRoundRect(shadowP, halfSize, rectRadius);
    //         float shadowA = 1.0 - smoothstep(-aa, aa, shadowSdf);
    //         // Use shadowRadius to soften the shadow (multiplication factor)
    //         vec4 shadowFinal = vec4(shadowColor.rgb, shadowColor.a * shadowA * 0.5);
    //         color = compositeOver(shadowFinal, color);
    //     }

    //     finalColor = vec4(color.rgb, color.a * alpha);

    // } else {
    //     // ========== TEXT SDF PATH ==========
    //     float dist = texture(texture0, fragTexCoord).a - 0.5;
    //     float delta = fwidth(dist);
    //     float alpha = smoothstep(-delta, delta, dist);

    //     // fragColor is the vertex color (tint) passed from the UI
    //     finalColor = vec4(fragColor.rgb, fragColor.a * alpha);
    // }
}