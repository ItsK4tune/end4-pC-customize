#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    vec2 halfpixel;
    vec2 offset;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 sum = texture(source, uv) * 4.0;
    sum += texture(source, uv - halfpixel * offset);
    sum += texture(source, uv + halfpixel * offset);
    sum += texture(source, uv + vec2(halfpixel.x, -halfpixel.y) * offset);
    sum += texture(source, uv - vec2(halfpixel.x, -halfpixel.y) * offset);
    fragColor = (sum / 8.0) * qt_Opacity;
}
