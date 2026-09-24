#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

float leafSDF(vec2 p, float size) {
    p.y += size * 0.1;
    float mainBody = length(vec2(p.x * 1.1, p.y * 0.8 + abs(p.x) * 0.4)) - size;
    float leftLobe = length(vec2(p.x + size * 0.45, p.y - size * 0.15)) - size * 0.55;
    float rightLobe = length(vec2(p.x - size * 0.45, p.y - size * 0.15)) - size * 0.55;
    return min(mainBody, min(leftLobe, rightLobe));
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

    vec3 baseColor1 = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.92, 0.32, 0.12);
    vec3 baseColor2 = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.95, 0.65, 0.15);

    for (int layer = 1; layer <= 2; layer++) {
        float l = float(layer);
        float layerSpeed = 35.0 + 25.0 * l;
        float sway = sin(time * 0.6 + l * 2.3) * (25.0 + 12.0 * l);
        vec2 layerCoord = flowCoord + vec2(sway - time * 10.0 * l, -time * layerSpeed);

        float cellSize = 160.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(15.7, 39.1)) + l * 47.9);

                if (spawn > density * 0.55) continue;

                vec2 rnd = hash22(cell + vec2(l * 19.3, l * 31.7));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.16) * cellSize;
                vec2 p = layerCoord - pInCell;

                float rot = time * (0.6 + 0.5 * spawn) + spawn * 6.28;
                p = rotate(p, rot);

                float flip = 0.35 + 0.65 * abs(cos(time * 1.2 + spawn * 6.28));
                p.x /= flip;

                float pSize = (8.0 + 4.0 * l + 2.0 * spawn) * particleSize * (1.0 + bass * 0.3);
                float d = leafSDF(p, pSize);

                float blurWidth = 1.3 + particleBlur * 6.0;
                if (d < blurWidth) {
                    float edge = 1.0 - smoothstep(0.0, blurWidth, d);
                    float centerGrad = clamp(1.0 - length(p) / pSize, 0.0, 1.0);
                    vec3 leafCol = mix(baseColor1, baseColor2, centerGrad + 0.3 * sin(spawn * 6.28));

                    if (mouseInfluence > 0.0) {
                        leafCol += vec3(0.4, 0.3, 0.15) * mouseInfluence;
                        float halo = exp(-length(p) / (pSize * 1.6)) * mouseInfluence * 0.75;
                        color += (leafCol + vec3(0.2)) * halo * particleAlpha;
                        alpha = min(1.0, alpha + halo * 0.6);
                    }
                    if (bass > 0.05) {
                        leafCol += baseColor2 * bass * 0.3;
                    }

                    float leafAlpha = edge * (0.7 + 0.3 * rnd.y) * particleAlpha;
                    color = mix(color, leafCol, leafAlpha * (1.0 - alpha));
                    alpha = alpha + leafAlpha * (1.0 - alpha);
                }
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
