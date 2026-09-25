#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

float leafSDF(vec2 p, float size) {
    p.y += size * 0.25;
    float body = length(vec2(p.x * 1.35, p.y * 0.8 + abs(p.x) * 0.4)) - size;
    float lobeL = length(p - vec2(-size * 0.65, size * 0.1)) - size * 0.42;
    float lobeR = length(p - vec2(size * 0.65, size * 0.1)) - size * 0.42;
    float d = min(body, min(lobeL, lobeR));
    float stem = length(vec2(p.x * 5.0, p.y + size * 0.7)) - size * 0.35;
    return min(d, stem);
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

    bool hasPrimary = primaryColor.a > 0.05;
    bool hasSecondary = secondaryColor.a > 0.05;
    vec3 autumnGold = hasPrimary ? primaryColor.rgb : vec3(0.96, 0.65, 0.14);
    vec3 autumnCrimson = hasSecondary ? secondaryColor.rgb : (hasPrimary ? mix(primaryColor.rgb, vec3(0.0), 0.25) : vec3(0.85, 0.22, 0.10));
    vec3 autumnAmber = mix(autumnCrimson, autumnGold, 0.5);

    for (int layer = 1; layer <= 2; layer++) {
        float l = float(layer);
        float layerSpeed = (35.0 + 25.0 * l) * (1.0 + bass * 0.25);
        float sway = sin(time * (0.6 + mid * 0.5) + l * 2.3) * (25.0 + 12.0 * l + mid * 12.0);
        vec2 layerCoord = flowCoord + vec2(sway - time * layerSpeed * tan(windAngle), -time * layerSpeed);

        float cellSize = 170.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(15.7, 39.1)) + l * 47.9);

                if (spawn > min(density * 0.6, 1.0)) continue;

                vec2 rnd = hash22(cell + vec2(l * 19.3, l * 31.7));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.2) * cellSize;
                vec2 p = layerCoord - pInCell;
                float unscaledDist = length(p);

                float rot = time * (0.6 + 0.5 * spawn + mid * 0.5) + spawn * 6.28 + windAngle * 0.7;
                p = rotate(p, rot);

                float flipX = 0.35 + 0.65 * abs(cos(time * 1.2 + spawn * 6.28));
                float flipY = 0.65 + 0.35 * abs(sin(time * 0.9 + spawn * 3.14));
                vec2 scaledP = vec2(p.x / flipX, p.y / flipY);

                float pSize = (8.0 + 5.0 * l + 3.0 * spawn) * particleSize * (1.0 + bass * 0.35);
                float d = leafSDF(scaledP, pSize);

                float blurWidth = 1.3 + particleBlur * 6.0;
                if (d < blurWidth) {
                    float edge = 1.0 - smoothstep(0.0, blurWidth, d);
                    float centerGrad = clamp(1.0 - unscaledDist / pSize, 0.0, 1.0);

                    vec3 leafBase = mix(autumnCrimson, autumnGold, rnd.x);
                    leafBase = mix(leafBase, autumnAmber, centerGrad);

                    if (mouseInfluence > 0.0) {
                        leafBase += autumnGold * 0.4 * mouseInfluence;
                    }
                    if (bass > 0.05) {
                        leafBase += autumnGold * bass * 0.35;
                    }
                    if (treble > 0.05) {
                        leafBase += autumnCrimson * treble * 0.4 * edge;
                    }

                    float cellEnvelope = smoothstep(cellSize * 1.8, cellSize * 1.2, unscaledDist);
                    float leafAlpha = edge * (0.75 + 0.25 * rnd.y) * particleAlpha * cellEnvelope;

                    if (mouseInfluence > 0.0) {
                        float halo = exp(-unscaledDist / (pSize * 1.6)) * mouseInfluence * 0.75 * cellEnvelope;
                        color += (leafBase + autumnGold * 0.2) * halo * particleAlpha;
                        alpha = min(1.0, alpha + halo * 0.6);
                    }

                    color = mix(color, leafBase, leafAlpha * (1.0 - alpha));
                    alpha = alpha + leafAlpha * (1.0 - alpha);
                }
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
            color += (autumnGold + vec3(0.25)) * wave * 0.75 * particleAlpha;
            alpha = min(1.0, alpha + wave * 0.65);
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
