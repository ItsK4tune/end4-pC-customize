import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property string thumbnailPath: {
        if (sourcePath.length == 0) return;
        const resolvedUrlWithoutFileProtocol = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encodedUrlWithoutFileProtocol = resolvedUrlWithoutFileProtocol.split("/").map(part => encodeURIComponent(part)).join("/");
        const md5Hash = Qt.md5(`file://${encodedUrlWithoutFileProtocol}`);
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`;
    }
    property bool fallbackToSource: false
    source: (fallbackToSource || !thumbnailPath || thumbnailPath.length === 0)
        ? (sourcePath && sourcePath.length > 0 ? Qt.resolvedUrl(sourcePath) : "")
        : thumbnailPath

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onSourcePathChanged: {
        fallbackToSource = false;
    }

    onStatusChanged: {
        if (status === Image.Error && !fallbackToSource && sourcePath && sourcePath.length > 0) {
            fallbackToSource = true;
        }
    }

    function reload() {
        fallbackToSource = false;
        const p = thumbnailPath;
        source = "";
        source = p;
    }

    Timer {
        id: thumbnailGenTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.generateThumbnail || sourceSize.width <= 0 || sourceSize.height <= 0 || !root.sourcePath || !root.thumbnailPath) return;
            thumbnailGeneration.running = false;
            thumbnailGeneration.running = true;
        }
    }

    onSourceSizeChanged: {
        if (!root.generateThumbnail || sourceSize.width <= 0 || sourceSize.height <= 0) return;
        thumbnailGenTimer.restart();
    }

    Process {
        id: thumbnailGeneration
        command: {
            const maxSize = Images.thumbnailSizes[root.thumbnailSizeName] || 512;
            const thumbPath = FileUtils.trimFileProtocol(root.thumbnailPath);
            const srcPath = FileUtils.trimFileProtocol(root.sourcePath);
            return [
                "bash", "-c",
                'mkdir -p "$(dirname "$1")" && { [ -f "$1" ] && exit 0 || { tmp="$1.$$.tmp.png"; magick "$2" -resize "${3}x${3}" "$tmp" && mv "$tmp" "$1" && exit 1; exit 2; }; }',
                "thumbgen",
                thumbPath,
                srcPath,
                String(maxSize)
            ];
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1) {
                root.reload();
            }
        }
    }
}
