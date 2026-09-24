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

    vec3 baseColor1 = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(1.0, 0.74, 0.83);
    vec3 baseColor2 = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.96, 0.48, 0.62);

    for (int layer = 1; layer <= 2; layer++) {
        float l = float(layer);
        float layerSpeed = 45.0 + 35.0 * l;
        float sway = sin(time * 0.8 + l * 2.0) * (20.0 + 15.0 * l);
        vec2 layerCoord = flowCoord + vec2(sway - time * 18.0 * l, -time * layerSpeed);

        float cellSize = 95.0;
        vec2 grid = layerCoord / cellSize;
        vec2 currentCell = floor(grid);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                float spawn = hash11(dot(cell, vec2(17.3, 31.7)) + l * 43.1);

                if (spawn > density * 0.5) continue;

                vec2 rnd = hash22(cell + vec2(l * 11.3, l * 29.7));
                vec2 pInCell = (cell + vec2(0.5) + (rnd - 0.5) * 0.35) * cellSize;
                vec2 p = layerCoord - pInCell;

                float rot = time * (0.8 + 0.4 * spawn) + spawn * 6.28;
                p = rotate(p, rot);

                float flip = 0.35 + 0.65 * abs(cos(time * 1.4 + spawn * 6.28));
                p.x /= flip;

                float pSize = (7.0 + 4.0 * l + 2.0 * spawn) * particleSize * (1.0 + bass * 0.3);
                float d = petalSDF(p, pSize);

                float blurWidth = 1.2 + particleBlur * 7.0;
                if (d < blurWidth) {
                    float edge = 1.0 - smoothstep(0.0, blurWidth, d);
                    float centerGrad = clamp(1.0 - length(p) / pSize, 0.0, 1.0);
                    vec3 petalCol = mix(baseColor2, baseColor1, centerGrad);

                    if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                        petalCol += vec3(0.3, 0.25, 0.1) * mouseInfluence * mouseStrength;
                    }
                    if (bass > 0.05) {
                        petalCol += baseColor1 * bass * 0.3;
                    }

                    float petalAlpha = edge * (0.65 + 0.35 * rnd.y) * particleAlpha;
                    color = mix(color, petalCol, petalAlpha * (1.0 - alpha));
                    alpha = alpha + petalAlpha * (1.0 - alpha);
                }
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
