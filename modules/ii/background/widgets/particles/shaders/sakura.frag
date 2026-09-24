#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

float petalSDF(vec2 p, float size) {
    p.y += size * 0.2;
    float d = length(vec2(p.x * 1.25, p.y * 0.85 + abs(p.x) * 0.35)) - size;
    float notch = length(vec2(p.x * 2.5, p.y - size * 0.9)) - size * 0.25;
    return max(d, -notch);
}

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

    vec3 baseColor1 = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(1.0, 0.74, 0.83);
    vec3 baseColor2 = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.96, 0.48, 0.62);

    vec2 fallDir = vec2(sin(windAngle), cos(windAngle));

    for (int layer = 1; layer <= 2; layer++) {
        float l = float(layer);
        float layerSpeed = (40.0 + 30.0 * l) * (1.0 + bass * 0.25);
        float sway = sin(time * (0.7 + mid * 0.6) + l * 2.0) * (20.0 + 12.0 * l + mid * 14.0);
        vec2 layerCoord = flowCoord + vec2(sway, 0.0) + fallDir * (-time * layerSpeed);

        float cellSize = 160.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(17.3, 31.7)) + l * 43.1);

                if (spawn > min(density * 0.6, 1.0)) continue;

                vec2 rnd = hash22(cell + vec2(l * 11.3, l * 29.7));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.2) * cellSize;
                vec2 p = layerCoord - pInCell;
                float unscaledDist = length(p);

                float rot = time * (0.8 + 0.4 * spawn + mid * 0.5) + spawn * 6.28 + windAngle * 0.5;
                p = rotate(p, rot);

                float flip = 0.35 + 0.65 * abs(cos(time * 1.4 + spawn * 6.28));
                vec2 scaledP = vec2(p.x / flip, p.y);

                float pSize = (7.0 + 4.0 * l + 2.0 * spawn) * particleSize * (1.0 + bass * 0.35);
                float d = petalSDF(scaledP, pSize);

                float blurWidth = 1.2 + particleBlur * 6.0;
                if (d < blurWidth) {
                    float edge = 1.0 - smoothstep(0.0, blurWidth, d);
                    float centerGrad = clamp(1.0 - unscaledDist / pSize, 0.0, 1.0);
                    vec3 petalCol = mix(baseColor2, baseColor1, centerGrad);

                    if (mouseInfluence > 0.0) {
                        petalCol += vec3(0.4, 0.3, 0.15) * mouseInfluence;
                    }
                    if (bass > 0.05) {
                        petalCol += baseColor1 * bass * 0.35;
                    }
                    if (treble > 0.05) {
                        petalCol += vec3(0.4, 0.35, 0.5) * treble * edge;
                    }

                    float cellEnvelope = smoothstep(cellSize * 1.8, cellSize * 1.2, unscaledDist);
                    float petalAlpha = edge * (0.7 + 0.3 * rnd.y) * particleAlpha * cellEnvelope;

                    if (mouseInfluence > 0.0) {
                        float halo = exp(-unscaledDist / (pSize * 1.6)) * mouseInfluence * 0.75 * cellEnvelope;
                        color += (petalCol + vec3(0.2)) * halo * particleAlpha;
                        alpha = min(1.0, alpha + halo * 0.6);
                    }

                    color = mix(color, petalCol, petalAlpha * (1.0 - alpha));
                    alpha = alpha + petalAlpha * (1.0 - alpha);
                }
            }
        }
    }

    if (clickProgress < 1.0) {
        float clickDist = length(fragCoord - clickPos);
        float waveRadius = clickProgress * 300.0;
        float wave = smoothstep(22.0, 0.0, abs(clickDist - waveRadius)) * (1.0 - clickProgress);
        color += (baseColor1 + vec3(0.25)) * wave * 0.75 * particleAlpha;
        alpha = min(1.0, alpha + wave * 0.65);
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
