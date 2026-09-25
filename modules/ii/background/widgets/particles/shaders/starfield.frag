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

    for (int i = 0; i < 4; i++) {
        float prog = (i == 0) ? clickProgress.x : ((i == 1) ? clickProgress.y : ((i == 2) ? clickProgress.z : clickProgress.w));
        if (prog < 1.0) {
            vec2 cPos = (i == 0) ? clickPos0 : ((i == 1) ? clickPos1 : ((i == 2) ? clickPos2 : clickPos3));
            float cDist = length(fragCoord - cPos);
            float waveR = prog * 320.0;
            float shock = smoothstep(45.0, 0.0, abs(cDist - waveR)) * pow(1.0 - prog, 1.5);
            vec2 pushDir = (cDist > 1.0) ? ((fragCoord - cPos) / cDist) : vec2(0.0, 1.0);
            flowCoord += pushDir * shock * 35.0;
        }
    }

    bool hasPrimary = primaryColor.a > 0.05;
    bool hasSecondary = secondaryColor.a > 0.05;
    vec3 starBaseCol = hasPrimary ? primaryColor.rgb : vec3(0.85, 0.92, 1.0);
    vec3 starGlowCol = hasSecondary ? secondaryColor.rgb : (hasPrimary ? mix(primaryColor.rgb, vec3(1.0), 0.3) : vec3(0.55, 0.75, 1.0));

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float fallSpeed = (6.0 + 8.0 * l) * (1.0 + bass * 0.12 + mid * 0.08);
        float sway = sin(time * 0.2 + l * 2.0) * (5.0 * l);
        vec2 layerCoord = flowCoord + vec2(sway - windDrift * fallSpeed, -time * fallSpeed);

        float cellSize = 150.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(43.1, 89.3)) + l * 29.5);

                if (spawn > min(density * (0.5 + 0.15 * l), 1.0)) continue;

                vec2 rnd = hash22(cell + vec2(l * 13.9, l * 27.1));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.3) * cellSize;
                vec2 p = layerCoord - pInCell;
                float dist = length(p);

                float rndPhase = hash11(rnd.x * 53.31);
                float twinkle = pow(0.5 + 0.5 * sin(time * (1.5 + 2.0 * rnd.x) + rndPhase * 6.28), 3.0);
                twinkle = mix(0.3, 1.0, twinkle) * (1.0 + bass * 0.2 + treble * 0.15);

                float starSize = (1.2 + 0.7 * l + 0.6 * rnd.y) * particleSize * (1.0 + bass * 0.1);
                float maxGlow = starSize * (3.5 + particleBlur * 4.0);

                if (dist < maxGlow) {
                    float distFade = smoothstep(maxGlow, maxGlow * 0.6, dist);
                    float core = smoothstep(starSize, 0.0, dist);
                    float glow = exp(-dist / (starSize * 1.5)) * distFade;

                    float spikeX = smoothstep(starSize * 0.4, 0.0, abs(p.x)) * smoothstep(starSize * 4.0, 0.0, abs(p.y));
                    float spikeY = smoothstep(starSize * 0.4, 0.0, abs(p.y)) * smoothstep(starSize * 4.0, 0.0, abs(p.x));
                    float spikes = (spikeX + spikeY) * 0.4 * float(l >= 2.0);

                    float starAlpha = (core * 0.9 + glow * 0.5 + spikes) * twinkle * (0.35 + 0.22 * l) * particleAlpha;

                    vec3 currentCol = mix(starBaseCol, starGlowCol, rnd.x);

                    if (mouseInfluence > 0.0) {
                        currentCol += starBaseCol * 0.4 * mouseInfluence;
                        starAlpha = min(1.0, starAlpha * (1.0 + mouseInfluence * 2.5));
                    }
                    if (treble > 0.05) {
                        currentCol += starGlowCol * 0.25 * treble;
                    }

                    color += currentCol * starAlpha;
                    alpha = min(1.0, alpha + starAlpha * 0.75);
                }
            }
        }
    }

    for (int i = 0; i < 4; i++) {
        float prog = (i == 0) ? clickProgress.x : ((i == 1) ? clickProgress.y : ((i == 2) ? clickProgress.z : clickProgress.w));
        if (prog < 1.0) {
            vec2 cPos = (i == 0) ? clickPos0 : ((i == 1) ? clickPos1 : ((i == 2) ? clickPos2 : clickPos3));
            float clickDist = length(fragCoord - cPos);
            float waveRadius = prog * 320.0;
            float wave = smoothstep(7.0, 0.0, abs(clickDist - waveRadius)) * pow(1.0 - prog, 1.8);
            float core = exp(-clickDist / 28.0) * max(0.0, 1.0 - prog * 3.5) * 0.4;
            color += (starBaseCol + vec3(0.15)) * (wave * 0.35 + core) * particleAlpha;
            alpha = min(1.0, alpha + wave * 0.25 + core * 0.3);
        }
    }

    fragColor = vec4(color, alpha) * qt_Opacity;
}
