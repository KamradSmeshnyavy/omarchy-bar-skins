#version 440
// Перекраска модуля бара в один цвет (RiceDress: тёмные значки на плитке Bruteon, акцент Cozytile): цвет ink там, где
// модуль непрозрачен, с его же сглаживанием краёв. Слой Loader-а модуля — source (premultiplied alpha).
// Сборка: qsb --qt6 -o ricetint.frag.qsb ricetint.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float a = texture(source, qt_TexCoord0).a;
    fragColor = vec4(ink.rgb * ink.a, ink.a) * a * qt_Opacity;
}
