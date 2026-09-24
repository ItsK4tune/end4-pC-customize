#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 fragCoord = uv * resolution;
    vec3 color = vec3(0.0);
    float alpha = 0.0;

    vec2 flowCoord = fragCoord;
    float distMouse = length(fragCoord - mousePos);
    float mouseInfluence = 0.0;

    if (distMouse < mouseRadius && mouseRadius > 0.0) {
        float normDist = 1.0 - distMouse / mouseRadius;
        mouseInfluence = normDist;
        vec2 dir = normalize(fragCoord - mousePos);
        if (mouseMode == 1.0) {
            flowCoord += dir * normDist * mouseStrength * 45.0;
        } else if (mouseMode == 2.0) {
            flowCoord -= dir * normDist * mouseStrength * 30.0;
        } else if (mouseMode == 4.0) {
            vec2 tangent = vec2(-dir.y, dir.x);
            flowCoord += tangent * normDist * mouseStrength * 40.0;
        }
    }

    vec3 snowColor = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.92, 0.95, 1.0);

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float fallSpeed = 30.0 + 25.0 * l;
        float sway = sin(time * (0.7 + 0.2 * l) + l * 1.5) * (12.0 * l);
        vec2 layerCoord = flowCoord + vec2(sway, -time * fallSpeed);

        float cellSize = 80.0 / (0.7 + 0.3 * l);
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(23.7, 41.3)) + l * 37.1);

                if (spawn > density * 0.55) continue;

                vec2 rnd = hash22(cell + vec2(l * 17.1, l * 31.9));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.4) * cellSize;
                vec2 p = layerCoord - pInCell;
                float dist = length(p);

                float radius = (1.2 + 0.9 * l + 0.6 * rnd.x) * particleSize * (1.0 + bass * 0.2);
                float blurWidth = radius * (1.5 + particleBlur * 3.5);

                if (dist < blurWidth) {
                    float flakeAlpha = smoothstep(blurWidth, 0.0, dist) * (0.3 + 0.22 * l) * particleAlpha;
                    vec3 currentFlakeCol = snowColor;

                    if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                        currentFlakeCol += vec3(0.2, 0.3, 0.5) * mouseInfluence * mouseStrength;
                        flakeAlpha = min(1.0, flakeAlpha * (1.0 + mouseInfluence * 1.5));
                    }
                    if (bass > 0.05) {
                        flakeAlpha = min(1.0, flakeAlpha * (1.0 + bass * 0.4));
                    }

                    color = mix(color, currentFlakeCol, flakeAlpha * (1.0 - alpha));
                    alpha = alpha + flakeAlpha * (1.0 - alpha);
                }
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
