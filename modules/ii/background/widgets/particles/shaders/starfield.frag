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
            flowCoord += dir * softFalloff * mouseStrength * 60.0;
        } else if (mode == 2) {
            flowCoord -= dir * softFalloff * mouseStrength * 45.0;
        } else if (mode == 4) {
            vec2 delta = fragCoord - mousePos;
            float angle = (1.0 - normDist) * (1.0 - normDist) * mouseStrength * 2.2;
            flowCoord = mousePos + rotate(delta, angle);
        } else if (mode == 3) {
            mouseInfluence = pow(1.0 - normDist, 2.0) * mouseStrength;
        }
    }

    vec3 starBaseCol = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.85, 0.92, 1.0);
    vec3 starGlowCol = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.55, 0.75, 1.0);

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float fallSpeed = 6.0 + 8.0 * l;
        float sway = sin(time * 0.2 + l * 2.0) * (5.0 * l);
        vec2 layerCoord = flowCoord + vec2(sway, -time * fallSpeed);

        float cellSize = 130.0 / (0.6 + 0.4 * l);
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(43.1, 89.3)) + l * 29.5);

                if (spawn > density * 0.55) continue;

                vec2 rnd = hash22(cell + vec2(l * 13.9, l * 27.1));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.16) * cellSize;
                vec2 p = layerCoord - pInCell;
                float dist = length(p);

                float rndPhase = hash11(rnd.x * 53.31);
                float twinkle = pow(0.5 + 0.5 * sin(time * (1.5 + 2.0 * rnd.x) + rndPhase * 6.28), 3.0);
                float starSize = (1.0 + 0.9 * l + 0.7 * rnd.y) * particleSize * (1.0 + bass * 0.25);

                float maxDist = starSize * (3.0 + particleBlur * 2.5);
                if (dist < maxDist) {
                    float core = smoothstep(starSize, 0.0, dist);
                    float glow = exp(-dist / (starSize * (1.1 + particleBlur * 1.3))) * 0.5;

                    float spike = 0.0;
                    if (rnd.x > 0.65) {
                        float crossSpike = max(0.0, 1.0 - abs(p.x) / (starSize * 3.0)) * max(0.0, 1.0 - abs(p.y) / (starSize * 0.7))
                                         + max(0.0, 1.0 - abs(p.y) / (starSize * 3.0)) * max(0.0, 1.0 - abs(p.x) / (starSize * 0.7));
                        spike = crossSpike * 0.35;
                    }

                    float starAlpha = (core + glow + spike) * (0.35 + 0.65 * twinkle) * (0.3 + 0.23 * l) * particleAlpha;
                    vec3 currentStarCol = mix(starBaseCol, starGlowCol, rnd.y);

                    if (mouseInfluence > 0.0) {
                        currentStarCol += vec3(0.4, 0.4, 0.6) * mouseInfluence;
                        starAlpha = min(1.0, starAlpha * (1.0 + mouseInfluence * 2.0));
                    }
                    if (bass > 0.05) {
                        currentStarCol += starGlowCol * bass * 0.4;
                    }

                    color += currentStarCol * starAlpha;
                    alpha = min(1.0, alpha + starAlpha * 0.6);
                }
            }
        }
    }

    fragColor = vec4(color, alpha) * qt_Opacity;
}
