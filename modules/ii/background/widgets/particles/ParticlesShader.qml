import QtQuick

ShaderEffect {
    id: root

    required property string style
    property real time: 0.0
    property real speed: 1.0
    property real density: 1.0
    property real particleSize: 1.0
    property real particleAlpha: 1.0
    property real particleBlur: 0.0
    property real mouseRadius: 180.0
    property real mouseStrength: 1.0
    property real mouseMode: 1.0
    property real bass: 0.0
    property real mid: 0.0
    property real treble: 0.0
    property real windAngle: 0.0
    property real clickProgress: 1.0
    readonly property vector2d resolution: Qt.vector2d(width, height)
    property vector2d mousePos: Qt.vector2d(-9999.0, -9999.0)
    property vector2d clickPos: Qt.vector2d(-9999.0, -9999.0)
    property color primaryColor: Qt.rgba(0, 0, 0, 0)
    property color secondaryColor: Qt.rgba(0, 0, 0, 0)

    blending: true
    fragmentShader: Qt.resolvedUrl(`shaders/${style}.frag.qsb`)
}
