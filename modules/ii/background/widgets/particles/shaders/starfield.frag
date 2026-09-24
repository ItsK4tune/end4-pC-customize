#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 fragCoord = uv * resolution;
    vec3 color = vec3(0.0);
    float alpha = 0.0;

    float t = time * speed * 0.4;
    vec3 starBaseCol = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.85, 0.92, 1.0);
    vec3 starGlowCol = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.55, 0.75, 1.0);

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float cellSize = (70.0 / l) / max(density, 0.2);
        vec2 gridCoord = fragCoord / cellSize;
        vec2 currentCell = floor(gridCoord);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                vec2 rnd = hash22(cell + vec2(l * 31.1, l * 47.7));
                float rndPhase = hash11(rnd.x * 53.31);

                vec2 drift = vec2(
                    sin(t * 0.3 + rnd.y * 6.28) * 8.0 * l,
                    -mod(t * (10.0 * l + 5.0 * rnd.x) + rnd.y * 1000.0, resolution.y + 60.0) + 30.0
                );

                vec2 basePos = (cell + vec2(0.5)) * cellSize;
                vec2 particlePos = vec2(mod(basePos.x + drift.x, resolution.x), mod(basePos.y + drift.y, resolution.y));

                vec2 toParticle = particlePos - mousePos;
                float distToMouse = length(toParticle);
                float mouseInfluence = 0.0;

                if (distToMouse < mouseRadius && mouseRadius > 0.0) {
                    float normDist = 1.0 - (distToMouse / mouseRadius);
                    mouseInfluence = normDist;
                    if (mouseMode == 1.0) {
                        particlePos += (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 45.0;
                    } else if (mouseMode == 2.0) {
                        particlePos -= (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 30.0;
                    }
                }

                vec2 p = fragCoord - particlePos;
                float dist = length(p);

                float twinkle = pow(0.5 + 0.5 * sin(t * (2.0 + 3.0 * rnd.x) + rndPhase * 6.28), 3.0);
                float starSize = (1.2 + 1.2 * l + 1.0 * rnd.y) * particleSize;

                if (dist < starSize * 5.0) {
                    float core = smoothstep(starSize, 0.0, dist);
                    float glow = exp(-dist / (starSize * 1.5)) * 0.5;

                    float spike = 0.0;
                    if (rnd.x > 0.6) {
                        float crossSpike = max(0.0, 1.0 - abs(p.x) / (starSize * 4.0)) * max(0.0, 1.0 - abs(p.y) / (starSize * 0.8))
                                         + max(0.0, 1.0 - abs(p.y) / (starSize * 4.0)) * max(0.0, 1.0 - abs(p.x) / (starSize * 0.8));
                        spike = crossSpike * 0.35;
                    }

                    float starAlpha = (core + glow + spike) * (0.35 + 0.65 * twinkle) * (0.3 + 0.23 * l) * particleAlpha;
                    vec3 currentStarCol = mix(starBaseCol, starGlowCol, rnd.y);

                    if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                        currentStarCol += vec3(0.4, 0.4, 0.6) * mouseInfluence * mouseStrength;
                        starAlpha = min(1.0, starAlpha * (1.0 + mouseInfluence * 2.5));
                    }

                    color += currentStarCol * starAlpha;
                    alpha = min(1.0, alpha + starAlpha * 0.6);
                }
            }
        }
    }

    fragColor = vec4(color, alpha) * qt_Opacity;
}
