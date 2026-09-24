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

    float t = time * speed * 0.6;
    float cellSize = 80.0 / max(density, 0.2);
    vec2 gridCoord = fragCoord / cellSize;
    vec2 currentCell = floor(gridCoord);

    vec3 baseColor1 = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(1.0, 0.74, 0.83);
    vec3 baseColor2 = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.96, 0.48, 0.62);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = currentCell + vec2(float(x), float(y));
            vec2 rnd = hash22(cell);
            float rndRot = hash11(rnd.x * 43.12);
            float rndSize = 0.7 + 0.6 * hash11(rnd.y * 17.54);

            float localSpeed = 0.6 + 0.8 * rnd.y;
            float fallY = mod(rnd.y * 1000.0 + t * localSpeed * 70.0, resolution.y + 160.0) - 80.0;
            float swayX = sin(t * 1.2 + rnd.x * 6.28) * 45.0 + (t * 20.0 * rnd.x);
            float fallX = mod(rnd.x * resolution.x + swayX, resolution.x + 160.0) - 80.0;

            vec2 particlePos = vec2(fallX, fallY);

            vec2 toParticle = particlePos - mousePos;
            float distToMouse = length(toParticle);
            float mouseInfluence = 0.0;

            if (distToMouse < mouseRadius && mouseRadius > 0.0) {
                float normDist = 1.0 - (distToMouse / mouseRadius);
                mouseInfluence = normDist;
                if (mouseMode == 1.0) {
                    particlePos += (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 60.0;
                } else if (mouseMode == 2.0) {
                    particlePos -= (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 40.0;
                }
            }

            vec2 p = fragCoord - particlePos;
            float rotAngle = t * (0.8 + rndRot) + rndRot * 6.28;
            p = rotate(p, rotAngle);

            float flip = 0.35 + 0.65 * abs(cos(t * 1.5 + rnd.x * 6.28));
            p.x /= flip;

            float pSize = (8.0 + 4.0 * rndSize) * particleSize;
            float d = petalSDF(p, pSize);

            if (d < 1.5) {
                float edge = 1.0 - smoothstep(0.0, 1.5, d);
                float centerGrad = clamp(1.0 - length(p) / pSize, 0.0, 1.0);
                vec3 petalCol = mix(baseColor2, baseColor1, centerGrad);

                if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                    petalCol += vec3(0.3, 0.25, 0.1) * mouseInfluence * mouseStrength;
                }

                float petalAlpha = edge * (0.65 + 0.35 * rnd.y) * particleAlpha;
                color = mix(color, petalCol, petalAlpha * (1.0 - alpha));
                alpha = alpha + petalAlpha * (1.0 - alpha);
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
