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
        float normDist = distMouse / mouseRadius;
        float softFalloff = smoothstep(0.0, 0.25, normDist) * (1.0 - smoothstep(0.25, 1.0, normDist));
        vec2 dir = (fragCoord - mousePos) / (distMouse + 8.0);
        int mode = int(mouseMode + 0.5);

        if (mode == 1) {
            flowCoord += dir * softFalloff * mouseStrength * 80.0;
        } else if (mode == 2) {
            flowCoord -= dir * softFalloff * mouseStrength * 60.0;
        } else if (mode == 4) {
            vec2 delta = fragCoord - mousePos;
            float angle = (1.0 - normDist) * (1.0 - normDist) * mouseStrength * 2.5;
            flowCoord = mousePos + rotate(delta, angle);
        } else if (mode == 3) {
            mouseInfluence = pow(1.0 - normDist, 2.0) * mouseStrength;
        }
    }

    vec3 baseBubbleCol = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.5, 0.8, 1.0);
    vec3 rainbowTint = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.9, 0.6, 0.95);

    for (int layer = 1; layer <= 2; layer++) {
        float l = float(layer);
        float riseSpeed = 30.0 + 20.0 * l;
        float sway = sin(time * (0.7 + 0.3 * l) + l * 2.1) * (15.0 * l);
        vec2 layerCoord = flowCoord + vec2(sway, time * riseSpeed);

        float cellSize = 180.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(19.1, 53.7)) + l * 17.3);

                if (spawn > min(density * 0.55, 1.0)) continue;

                vec2 rnd = hash22(cell + vec2(l * 21.1, l * 37.9));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.25) * cellSize;
                vec2 p = layerCoord - pInCell;
                float dist = length(p);

                float radius = (12.0 + 9.0 * rnd.x + 3.0 * l) * particleSize * (1.0 + bass * 0.25);
                float maxDist = radius * (1.2 + particleBlur * 1.5);

                if (dist < maxDist) {
                    float normD = dist / radius;
                    float ring = smoothstep(0.7, 0.95, normD) * (1.0 - smoothstep(0.98, 1.05 + particleBlur * 0.8, normD));
                    float innerGlow = smoothstep(0.95, 0.0, normD) * 0.14;

                    vec2 highlightPos = vec2(-radius * 0.35, -radius * 0.35);
                    float highlight = smoothstep(radius * 0.3, 0.0, length(p - highlightPos)) * 0.65;

                    float cellEnvelope = smoothstep(cellSize * 1.8, cellSize * 1.2, dist);
                    float bubbleAlpha = (ring * 0.75 + innerGlow + highlight) * (0.4 + 0.3 * l) * particleAlpha * cellEnvelope;
                    vec3 bCol = mix(baseBubbleCol, rainbowTint, 0.5 + 0.5 * sin(atan(p.y, p.x) * 2.0 + time));

                    if (mouseInfluence > 0.0) {
                        bCol += vec3(0.4, 0.4, 0.6) * mouseInfluence;
                        float halo = exp(-dist / (radius * 1.8)) * mouseInfluence * 0.8 * cellEnvelope;
                        color += (bCol + vec3(0.2)) * halo * particleAlpha;
                        alpha = min(1.0, alpha + halo * 0.6);
                    }
                    if (bass > 0.05) {
                        bubbleAlpha = min(1.0, bubbleAlpha * (1.0 + bass * 0.35));
                    }

                    color = mix(color, bCol, bubbleAlpha * (1.0 - alpha));
                    alpha = alpha + bubbleAlpha * (1.0 - alpha);
                }
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
