#version 440
#extension GL_GOOGLE_include_directive : enable
#include "common.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 fragCoord = uv * resolution;
    vec3 color = vec3(0.0);
    float alpha = 0.0;

    float t = time * speed * 0.8;
    vec3 snowColor = (primaryColor.a > 0.05) ? primaryColor.rgb : vec3(0.92, 0.95, 1.0);

    for (int layer = 1; layer <= 3; layer++) {
        float l = float(layer);
        float lScale = 0.5 + 0.5 * l;
        float cellSize = (60.0 / lScale) / max(density, 0.2);

        vec2 gridCoord = fragCoord / cellSize;
        vec2 currentCell = floor(gridCoord);

        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 cell = currentCell + vec2(float(x), float(y));
                vec2 rnd = hash22(cell + vec2(l * 13.7, l * 29.3));

                float fallSpeed = (40.0 + 35.0 * l + 20.0 * rnd.y);
                float fallY = mod(rnd.y * 1000.0 + t * fallSpeed, resolution.y + 80.0) - 40.0;
                float swayX = sin(t * (0.8 + 0.3 * l) + rnd.x * 6.28) * (15.0 * l);
                float fallX = mod(rnd.x * resolution.x + swayX, resolution.x + 80.0) - 40.0;

                vec2 particlePos = vec2(fallX, fallY);

                vec2 toParticle = particlePos - mousePos;
                float distToMouse = length(toParticle);
                float mouseInfluence = 0.0;

                if (distToMouse < mouseRadius && mouseRadius > 0.0) {
                    float normDist = 1.0 - (distToMouse / mouseRadius);
                    mouseInfluence = normDist;
                    if (mouseMode == 1.0) {
                        particlePos += (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 50.0;
                    } else if (mouseMode == 2.0) {
                        particlePos -= (toParticle / max(distToMouse, 1.0)) * normDist * mouseStrength * 35.0;
                    }
                }

                vec2 p = fragCoord - particlePos;
                float dist = length(p);
                float radius = (1.5 + 1.2 * l + 0.8 * rnd.x) * particleSize;

                if (dist < radius * 2.2) {
                    float flakeAlpha = smoothstep(radius * 2.0, 0.0, dist) * (0.3 + 0.22 * l) * particleAlpha;
                    vec3 currentFlakeCol = snowColor;

                    if (mouseMode == 3.0 && mouseInfluence > 0.0) {
                        currentFlakeCol += vec3(0.2, 0.3, 0.5) * mouseInfluence * mouseStrength;
                        flakeAlpha = min(1.0, flakeAlpha * (1.0 + mouseInfluence * 1.5));
                    }

                    color = mix(color, currentFlakeCol, flakeAlpha * (1.0 - alpha));
                    alpha = alpha + flakeAlpha * (1.0 - alpha);
                }
            }
        }
    }

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
