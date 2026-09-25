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
            float waveR = prog * 280.0;
            float shock = smoothstep(45.0, 0.0, abs(cDist - waveR)) * pow(1.0 - prog, 1.5);
            vec2 pushDir = (cDist > 1.0) ? ((fragCoord - cPos) / cDist) : vec2(0.0, 1.0);
            flowCoord += pushDir * shock * 35.0;
        }
    }

    bool hasPrimary = primaryColor.a > 0.05;
    bool hasSecondary = secondaryColor.a > 0.05;
    vec3 snowColor = hasPrimary ? primaryColor.rgb : vec3(0.92, 0.95, 1.0);
    vec3 snowGlow = hasSecondary ? secondaryColor.rgb : snowColor;

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float fallSpeed = (35.0 + 25.0 * l) * (1.0 + bass * 0.1);
        float sway = sin(time * (0.6 + 0.2 * l) + l * 1.5) * (12.0 * l + mid * 6.0);
        vec2 layerCoord = flowCoord + vec2(sway - windDrift * fallSpeed, -time * fallSpeed);

        float cellSize = 150.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(23.7, 41.3)) + l * 37.1);

                if (spawn > min(density * (0.5 + 0.15 * l), 1.0)) continue;

                vec2 rnd = hash22(cell + vec2(l * 17.1, l * 31.9));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.3) * cellSize;
                vec2 p = layerCoord - pInCell;
                float dist = length(p);

                float radius = (1.5 + 1.1 * l + 0.8 * rnd.x) * particleSize * (1.0 + bass * 0.15);
                float blurWidth = radius * (1.5 + particleBlur * 3.0);

                if (dist < blurWidth * 2.2) {
                    float flakeAlpha = smoothstep(blurWidth, 0.0, dist) * (0.35 + 0.22 * l) * particleAlpha;
                    vec3 currentFlakeCol = snowColor;

                    if (mouseInfluence > 0.0) {
                        currentFlakeCol += snowGlow * 0.4 * mouseInfluence;
                    }
                    if (bass > 0.05) {
                        flakeAlpha = min(1.0, flakeAlpha * (1.0 + bass * 0.18));
                    }
                    if (treble > 0.05) {
                        currentFlakeCol += snowGlow * 0.25 * treble;
                    }

                    float cellEnvelope = smoothstep(cellSize * 1.8, cellSize * 1.2, dist);
                    flakeAlpha *= cellEnvelope;

                    if (mouseInfluence > 0.0) {
                        float halo = exp(-dist / (radius * 3.0)) * mouseInfluence * 0.6 * cellEnvelope;
                        color += currentFlakeCol * halo * particleAlpha;
                        alpha = min(1.0, alpha + halo * 0.5);
                    }

                    color = mix(color, currentFlakeCol, flakeAlpha * (1.0 - alpha));
                    alpha = alpha + flakeAlpha * (1.0 - alpha);
                }
            }
        }
    }

    for (int i = 0; i < 4; i++) {
        float prog = (i == 0) ? clickProgress.x : ((i == 1) ? clickProgress.y : ((i == 2) ? clickProgress.z : clickProgress.w));
        if (prog < 1.0) {
            vec2 cPos = (i == 0) ? clickPos0 : ((i == 1) ? clickPos1 : ((i == 2) ? clickPos2 : clickPos3));
            float clickDist = length(fragCoord - cPos);
            float waveRadius = prog * 280.0;
            float wave = smoothstep(7.0, 0.0, abs(clickDist - waveRadius)) * pow(1.0 - prog, 1.8);
            float core = exp(-clickDist / 28.0) * max(0.0, 1.0 - prog * 3.5) * 0.4;
            color += (snowColor + vec3(0.15)) * (wave * 0.35 + core) * particleAlpha;
            alpha = min(1.0, alpha + wave * 0.25 + core * 0.3);
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
