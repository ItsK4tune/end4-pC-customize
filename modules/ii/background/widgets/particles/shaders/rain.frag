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
            flowCoord += pushDir * shock * 45.0;
        }
    }

    bool hasPrimary = primaryColor.a > 0.05;
    bool hasSecondary = secondaryColor.a > 0.05;
    vec3 rainTint = hasPrimary ? primaryColor.rgb : vec3(0.72, 0.85, 1.0);
    vec3 highlightTint = hasSecondary ? secondaryColor.rgb : (hasPrimary ? mix(primaryColor.rgb, vec3(1.0), 0.35) : vec3(0.92, 0.96, 1.0));

    float windSlant = tan(windAngle);

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float fallSpeed = (650.0 + 350.0 * l) * (1.0 + bass * 0.12);
        vec2 layerCoord = flowCoord + vec2(-windDrift * fallSpeed, -time * fallSpeed);

        vec2 skewedCoord = vec2(layerCoord.x - layerCoord.y * windSlant, layerCoord.y);

        float cellW = 80.0;
        float cellH = 260.0;
        vec2 grid = vec2(skewedCoord.x / cellW, skewedCoord.y / cellH);
        vec2 currentCell = floor(grid);

        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(13.1, 71.3)) + l * 29.3);

                if (spawn > min(density * 0.65, 1.0)) continue;

                vec2 rnd = hash22(cell + vec2(l * 15.3, l * 41.7));
                vec2 pInCell = vec2((cell.x + 0.5 + (rnd.x - 0.5) * 0.25) * cellW, (cell.y + 0.5 + (rnd.y - 0.5) * 0.25) * cellH);
                vec2 p = skewedCoord - pInCell;
                vec2 rotP = rotate(p, -windAngle);

                float streakLen = (28.0 + 22.0 * l + 18.0 * rnd.y) * particleSize * (1.0 + bass * 0.15 + mid * 0.1);
                float streakWidth = (0.75 + 0.35 * l) * (1.0 + particleBlur * 1.8);

                float dx = abs(rotP.x);
                float dy = rotP.y;

                if (dx < streakWidth * 3.5 && dy > -streakLen && dy < streakLen * 0.15) {
                    float xProfile = exp(-dx * dx / (streakWidth * streakWidth * 0.75));

                    float normY = clamp((dy + streakLen) / (streakLen * 1.15), 0.0, 1.0);
                    float yProfile = pow(normY, 2.0);

                    float dropHead = smoothstep(streakWidth * 1.8, 0.0, length(vec2(dx, dy - streakLen * 0.04))) * 0.65;

                    float streakAlpha = (xProfile * yProfile * 0.85 + dropHead) * (0.22 + 0.22 * l) * particleAlpha;

                    vec3 currentRainCol = mix(rainTint, highlightTint, dropHead);

                    if (mouseInfluence > 0.0) {
                        currentRainCol += highlightTint * mouseInfluence * 0.6;
                        streakAlpha = min(1.0, streakAlpha * (1.0 + mouseInfluence * 2.2));
                    }
                    if (bass > 0.05) {
                        streakAlpha = min(1.0, streakAlpha * (1.0 + bass * 0.15));
                    }
                    if (treble > 0.05) {
                        currentRainCol += highlightTint * treble * 0.25;
                    }

                    color = mix(color, currentRainCol, streakAlpha * (1.0 - alpha));
                    alpha = alpha + streakAlpha * (1.0 - alpha);
                }
            }
        }
    }

    float bottomZone = smoothstep(resolution.y - 100.0, resolution.y, fragCoord.y);
    if (bottomZone > 0.0) {
        float splashCellSize = 75.0;
        vec2 splashGrid = fragCoord / splashCellSize;
        vec2 sCell = floor(splashGrid);

        for (int sy = -1; sy <= 1; sy++) {
            for (int sx = -1; sx <= 1; sx++) {
                vec2 c = sCell + vec2(float(sx), float(sy));
                float sSpawn = hash11(dot(c, vec2(53.1, 91.7)));
                if (sSpawn > density * 0.5) continue;

                vec2 sRnd = hash22(c + vec2(33.1, 77.9));
                float sCycle = fract(time * (1.6 + 1.2 * sRnd.x) + sRnd.y);

                vec2 sCenter = (c + vec2(0.3 + 0.4 * sRnd.x, 0.7 + 0.2 * sRnd.y)) * splashCellSize;
                vec2 sp = fragCoord - sCenter;
                float sDist = length(sp);

                float ringRadius = sCycle * 16.0 * particleSize;
                float ringWidth = 1.4 + particleBlur * 1.4;
                float ring = smoothstep(ringWidth, 0.0, abs(sDist - ringRadius)) * (1.0 - sCycle);

                float splashAlpha = ring * 0.3 * bottomZone * particleAlpha;
                vec3 splashCol = mix(rainTint, highlightTint, 0.5);

                color = mix(color, splashCol, splashAlpha * (1.0 - alpha));
                alpha = alpha + splashAlpha * (1.0 - alpha);
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
            color += (highlightTint + vec3(0.12)) * (wave * 0.35 + core) * particleAlpha;
            alpha = min(1.0, alpha + wave * 0.25 + core * 0.3);
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
