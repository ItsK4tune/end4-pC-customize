#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 fragCoord = uv * resolution;
    vec3 color = vec3(0.0);
    float alpha = 0.0;

    float t = time * speed * 0.5;
    float cellSize = 120.0 / max(density, 0.2);
    vec2 gridCoord = fragCoord / cellSize;
    vec2 currentCell = floor(gridCoord);

    vec3 warmYellow = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.95, 0.95, 0.35);
    vec3 limeGlow = (secondaryColor.a > 0.05) ? secondaryColor.rgb : vec3(0.65, 1.0, 0.25);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = currentCell + vec2(float(x), float(y));
            vec2 rnd = hash22(cell);
            float rndPhase = hash11(rnd.x * 67.89);

            vec2 basePos = (cell + vec2(0.5)) * cellSize;
            vec2 drift = vec2(
                sin(t * (0.8 + 0.5 * rnd.x) + rndPhase * 6.28) * (cellSize * 0.45),
                cos(t * (0.7 + 0.6 * rnd.y) + rnd.x * 6.28) * (cellSize * 0.45)
            );
            vec2 particlePos = basePos + drift;

            vec2 toParticle = particlePos - mousePos;
            float distToMouse = length(toParticle);
            float mouseInfluence = 0.0;

            if (distToMouse < mouseRadius && mouseRadius > 0.0) {
                float normDist = 1.0 - (distToMouse / mouseRadius);
                mouseInfluence = normDist;
                if (mouseMode == 1.0) {
                    particlePos += (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 55.0;
                } else if (mouseMode == 2.0) {
                    particlePos -= (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 40.0;
                }
            }

            vec2 p = fragCoord - particlePos;
            float dist = length(p);

            float pulse = pow(0.5 + 0.5 * sin(t * (1.5 + 2.0 * rnd.y) + rndPhase * 6.28), 2.5);
            pulse = mix(0.15, 1.0, pulse);

            float pSize = (16.0 + 10.0 * rnd.x) * particleSize;

            if (dist < pSize * 2.5) {
                float core = smoothstep(pSize * 0.25, 0.0, dist);
                float glow = exp(-dist / (pSize * 0.55));
                float flyAlpha = (core * 0.85 + glow * 0.65) * pulse * particleAlpha;

                vec3 flyCol = mix(warmYellow, limeGlow, rnd.x);

                if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                    flyCol += vec3(0.3, 0.3, 0.1) * mouseInfluence * mouseStrength;
                    flyAlpha = min(1.0, flyAlpha * (1.0 + mouseInfluence * 2.0));
                }

                color += flyCol * flyAlpha;
                alpha = min(1.0, alpha + flyAlpha * 0.7);
            }
        }
    }

    fragColor = vec4(color, alpha) * qt_Opacity;
}
