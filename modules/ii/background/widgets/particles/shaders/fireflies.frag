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

    float cellSize = 160.0;
    vec2 gridCoord = flowCoord / cellSize;
    vec2 currentCell = floor(gridCoord);

    vec3 warmYellow = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.95, 0.95, 0.35);
    vec3 limeGlow = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.65, 1.0, 0.25);

    vec2 windDrift = vec2(sin(windAngle), -cos(windAngle)) * time * 35.0;

    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 cell = currentCell + vec2(float(x), float(y));
            float spawn = hash11(dot(cell, vec2(37.1, 71.9)));

            if (spawn > min(density * 0.55, 1.0)) continue;

            vec2 rnd = hash22(cell);
            float rndPhase = hash11(rnd.x * 67.89);

            vec2 basePos = (cell + vec2(0.5)) * cellSize;
            vec2 drift = vec2(
                sin(time * (0.5 + 0.3 * rnd.x + mid * 0.4) + rndPhase * 6.28) * (cellSize * (0.18 + mid * 0.08)),
                cos(time * (0.4 + 0.4 * rnd.y + mid * 0.4) + rnd.x * 6.28) * (cellSize * (0.18 + mid * 0.08))
            ) + windDrift;
            vec2 particlePos = basePos + drift;

            vec2 p = flowCoord - particlePos;
            float dist = length(p);

            float pulse = pow(0.5 + 0.5 * sin(time * (1.1 + 1.3 * rnd.y) + rndPhase * 6.28), 2.5);
            pulse = mix(0.18, 1.0, pulse) * (1.0 + bass * 0.6 + treble * 0.4);

            float pSize = (10.0 + 6.0 * rnd.x) * particleSize * (1.0 + bass * 0.25);
            float maxGlowDist = pSize * (2.4 + particleBlur * 2.2);

            if (dist < maxGlowDist) {
                float distFade = smoothstep(maxGlowDist, maxGlowDist * 0.6, dist);
                float core = smoothstep(pSize * 0.25, 0.0, dist);
                float glow = exp(-dist / (pSize * 0.5 * (1.0 + particleBlur * 1.3))) * distFade;
                float flyAlpha = (core * 0.85 + glow * 0.65) * pulse * particleAlpha;

                vec3 flyCol = mix(warmYellow, limeGlow, rnd.x);

                if (mouseInfluence > 0.0) {
                    flyCol += warmYellow * 0.4 * mouseInfluence;
                    flyAlpha = min(1.0, flyAlpha * (1.0 + mouseInfluence * 2.5));
                }
                if (treble > 0.05) {
                    flyCol += limeGlow * 0.4 * treble;
                }

                color += flyCol * flyAlpha;
                alpha = min(1.0, alpha + flyAlpha * 0.7);
            }
        }
    }

    for (int i = 0; i < 4; i++) {
        float prog = (i == 0) ? clickProgress.x : ((i == 1) ? clickProgress.y : ((i == 2) ? clickProgress.z : clickProgress.w));
        if (prog < 1.0) {
            vec2 cPos = (i == 0) ? clickPos0 : ((i == 1) ? clickPos1 : ((i == 2) ? clickPos2 : clickPos3));
            float clickDist = length(fragCoord - cPos);
            float waveRadius = prog * 300.0;
            float wave = smoothstep(22.0, 0.0, abs(clickDist - waveRadius)) * (1.0 - prog);
            color += (warmYellow + vec3(0.3)) * wave * 0.8 * particleAlpha;
            alpha = min(1.0, alpha + wave * 0.7);
        }
    }

    fragColor = vec4(color, alpha) * qt_Opacity;
}
