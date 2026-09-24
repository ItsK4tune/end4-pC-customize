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
            flowCoord += dir * normDist * mouseStrength * 40.0;
        } else if (mouseMode == 2.0) {
            flowCoord -= dir * normDist * mouseStrength * 30.0;
        } else if (mouseMode == 4.0) {
            vec2 tangent = vec2(-dir.y, dir.x);
            flowCoord += tangent * normDist * mouseStrength * 40.0;
        }
    }

    vec3 rainCol = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.7, 0.85, 1.0);

    for (int layer = 1; layer <= 2; layer++) {
        float l = float(layer);
        float fallSpeed = 550.0 + 350.0 * l;
        float windX = time * (120.0 + 60.0 * l);
        vec2 layerCoord = flowCoord + vec2(windX, -time * fallSpeed);

        vec2 skewedCoord = vec2(layerCoord.x - layerCoord.y * 0.18, layerCoord.y);

        float cellW = 35.0;
        float cellH = 140.0;
        vec2 grid = vec2(skewedCoord.x / cellW, skewedCoord.y / cellH);
        vec2 currentCell = floor(grid);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(13.1, 71.3)) + l * 23.9);

                if (spawn > density * 0.6) continue;

                vec2 rnd = hash22(cell + vec2(l * 15.3, l * 41.7));
                vec2 pInCell = vec2((cell.x + 0.5 + (rnd.x - 0.5) * 0.4) * cellW, (cell.y + 0.5 + (rnd.y - 0.5) * 0.4) * cellH);
                vec2 p = skewedCoord - pInCell;

                float streakLen = (18.0 + 12.0 * l + 10.0 * rnd.y) * particleSize;
                float streakWidth = (1.0 + 0.5 * l) * (1.0 + particleBlur * 2.0);

                float dx = abs(p.x);
                float dy = abs(p.y);

                if (dx < streakWidth * 2.5 && dy < streakLen) {
                    float ax = 1.0 - smoothstep(0.0, streakWidth * 1.5, dx);
                    float ay = 1.0 - smoothstep(0.0, streakLen, dy);
                    float streakAlpha = ax * ay * (0.35 + 0.25 * l) * particleAlpha;

                    vec3 currentRainCol = rainCol;
                    if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                        currentRainCol += vec3(0.3, 0.4, 0.6) * mouseInfluence * mouseStrength;
                        streakAlpha = min(1.0, streakAlpha * (1.0 + mouseInfluence * 1.5));
                    }
                    if (bass > 0.05) {
                        streakAlpha = min(1.0, streakAlpha * (1.0 + bass * 0.3));
                    }

                    color = mix(color, currentRainCol, streakAlpha * (1.0 - alpha));
                    alpha = alpha + streakAlpha * (1.0 - alpha);
                }
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
