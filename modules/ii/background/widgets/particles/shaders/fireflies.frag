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
            flowCoord += dir * normDist * mouseStrength * 50.0;
        } else if (mouseMode == 2.0) {
            flowCoord -= dir * normDist * mouseStrength * 35.0;
        } else if (mouseMode == 4.0) {
            vec2 tangent = vec2(-dir.y, dir.x);
            flowCoord += tangent * normDist * mouseStrength * 45.0;
        }
    }

    float cellSize = 130.0;
    vec2 gridCoord = flowCoord / cellSize;
    vec2 currentCell = floor(gridCoord);

    vec3 warmYellow = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.95, 0.95, 0.35);
    vec3 limeGlow = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.65, 1.0, 0.25);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = currentCell + vec2(float(x), float(y));
            float spawn = hash11(dot(cell, vec2(37.1, 71.9)));

            if (spawn > density * 0.5) continue;

            vec2 rnd = hash22(cell);
            float rndPhase = hash11(rnd.x * 67.89);

            vec2 basePos = (cell + vec2(0.5)) * cellSize;
            vec2 drift = vec2(
                sin(time * (0.6 + 0.3 * rnd.x) + rndPhase * 6.28) * (cellSize * 0.22),
                cos(time * (0.5 + 0.4 * rnd.y) + rnd.x * 6.28) * (cellSize * 0.22)
            );
            vec2 particlePos = basePos + drift;

            vec2 p = flowCoord - particlePos;
            float dist = length(p);

            float pulse = pow(0.5 + 0.5 * sin(time * (1.2 + 1.5 * rnd.y) + rndPhase * 6.28), 2.5);
            pulse = mix(0.15, 1.0, pulse) * (1.0 + bass * 0.6);

            float pSize = (10.0 + 6.0 * rnd.x) * particleSize * (1.0 + bass * 0.25);
            float maxGlowDist = pSize * (2.2 + particleBlur * 2.5);

            if (dist < maxGlowDist) {
                float core = smoothstep(pSize * 0.25, 0.0, dist);
                float glow = exp(-dist / (pSize * 0.55 * (1.0 + particleBlur * 1.5)));
                float flyAlpha = (core * 0.85 + glow * 0.65) * pulse * particleAlpha;

                vec3 flyCol = mix(warmYellow, limeGlow, rnd.x);

                if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                    flyCol += vec3(0.3, 0.3, 0.1) * mouseInfluence * mouseStrength;
                    flyAlpha = min(1.0, flyAlpha * (1.0 + mouseInfluence * 2.0));
                }

                color += flyCol * flyAlpha;
                alpha = min(1.0, alpha + flyAlpha * 0.7);
            }
        }
    }

    fragColor = vec4(color, alpha) * qt_Opacity;
}
