pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: ""
    property string username: Quickshell.env("USER") || "user"
    property string hostname: ""
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: Quickshell.env("XDG_CURRENT_DESKTOP") || ""
    property string windowingSystem: (Quickshell.env("WAYLAND_DISPLAY") || "").length > 0 ? "Wayland" : "X11"
    property string cpu: ""
    property string gpu: ""
    property string memory: ""
    property string disk: ""
    property string shell: (Quickshell.env("SHELL") || "").split("/").pop()
    property string packages: ""
    property string installAge: ""
    property string kernelVersion: ""

    // Avatar Management System
    signal avatarChanged()

    readonly property string effectiveAvatar: {
        const pic = Config.options?.profile?.avatarPicture ?? "";
        if (pic.length > 0) {
            return pic.startsWith("file://") ? pic : "file://" + pic;
        }
        const folder = Config.options?.profile?.avatarPath ?? "";
        if (folder.length > 0) {
            const trimmed = FileUtils.trimFileProtocol(folder);
            if (/\.(png|jpe?g|webp|svg|gif|avif)$/i.test(trimmed)) {
                return folder.startsWith("file://") ? folder : "file://" + folder;
            }
        }
        return "file://" + Directories.home + "/.face";
    }

    function setAvatar(filePath) {
        if (!filePath) return;
        const cleanPath = FileUtils.trimFileProtocol(filePath.toString().trim());
        if (cleanPath.length === 0) return;
        Config.options.profile.avatarPicture = cleanPath;
        const userFace = Directories.home + "/.face";
        Quickshell.execDetached(["bash", "-c", `cp -f '${cleanPath}' '${userFace}' 2>/dev/null || true`]);
        root.avatarChanged();
    }

    function clearAvatar() {
        Config.options.profile.avatarPicture = "";
        Config.options.profile.avatarPath = "";
        root.avatarChanged();
    }

    function pickAvatar() {
        avatarPickerProc.running = false;
        avatarPickerProc.running = true;
    }

    Process {
        id: avatarPickerProc
        command: ["bash", "-c", `
            if command -v kdialog >/dev/null 2>&1; then
                kdialog --title "Select Avatar Image" --getopenfilename "$HOME" "Images (*.png *.jpg *.jpeg *.webp *.svg *.gif)" 2>/dev/null
            elif command -v zenity >/dev/null 2>&1; then
                zenity --file-selection --title="Select Avatar Image" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.svg *.gif" 2>/dev/null
            fi
        `]
        stdout: SplitParser {
            onRead: data => {
                const picked = data.trim();
                if (picked.length > 0) {
                    root.setAvatar(picked);
                }
            }
        }
    }

    function refresh() {
        getCpu.running = false;       getCpu.running = true
        getGpu.running = false;       getGpu.running = true
        getMemory.running = false;    getMemory.running = true
        getDisk.running = false;      getDisk.running = true
        root.shell = (Quickshell.env("SHELL") || "").split("/").pop()
        getPackages.running = false;  getPackages.running = true
        getInstallAge.running = false; getInstallAge.running = true
        getKernel.running = false; getKernel.running = true
    }

    function refreshHostname() {
        fileHostname.reload()
        root.hostname = fileHostname.text().trim()
    }

    Timer {
        triggeredOnStart: true
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            fileHostname.reload()
            root.hostname = fileHostname.text().trim()
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME="(.+?)"/m)
            const nameMatch = textOsRelease.match(/^NAME="(.+?)"/m)
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

            const idMatch = textOsRelease.match(/^ID="?(.+?)"?$/m)
            distroId = idMatch ? idMatch[1] : "unknown"

            const homeUrlMatch = textOsRelease.match(/^HOME_URL="(.+?)"/m)
            homeUrl = homeUrlMatch ? homeUrlMatch[1] : ""
            const documentationUrlMatch = textOsRelease.match(/^DOCUMENTATION_URL="(.+?)"/m)
            documentationUrl = documentationUrlMatch ? documentationUrlMatch[1] : ""
            const supportUrlMatch = textOsRelease.match(/^SUPPORT_URL="(.+?)"/m)
            supportUrl = supportUrlMatch ? supportUrlMatch[1] : ""
            const bugReportUrlMatch = textOsRelease.match(/^BUG_REPORT_URL="(.+?)"/m)
            bugReportUrl = bugReportUrlMatch ? bugReportUrlMatch[1] : ""
            const privacyPolicyUrlMatch = textOsRelease.match(/^PRIVACY_POLICY_URL="(.+?)"/m)
            privacyPolicyUrl = privacyPolicyUrlMatch ? privacyPolicyUrlMatch[1] : ""
            const logoFieldMatch = textOsRelease.match(/^LOGO="?(.+?)"?$/m)
            logo = logoFieldMatch ? logoFieldMatch[1] : ""

            switch (distroId) {
                case "artix":
                case "arch":        distroIcon = "arch-symbolic"; break
                case "endeavouros": distroIcon = "endeavouros-symbolic"; break
                case "cachyos":     distroIcon = "cachyos-symbolic"; break
                case "nixos":       distroIcon = "nixos-symbolic"; break
                case "fedora":      distroIcon = "fedora-symbolic"; break
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos":       distroIcon = "ubuntu-symbolic"; break
                case "debian":
                case "raspbian":
                case "kali":        distroIcon = "debian-symbolic"; break
                case "funtoo":
                case "gentoo":      distroIcon = "gentoo-symbolic"; break
                default:            distroIcon = "arch-symbolic"; break
            }
            if (textOsRelease.toLowerCase().includes("nyarch"))
                distroIcon = "nyarch-symbolic"

            if (logo.trim().length === 0)
                logo = distroIcon
        }
    }

    FileView {
        id: fileHostname
        path: "/etc/hostname"
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
    }

    Process {
        id: getKernel
        running: false
        command: ["uname", "-r"]
        stdout: SplitParser { onRead: data => root.kernelVersion = data.trim() }
    }

    Process {
        id: getCpu
        running: false
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2- | sed 's/^ //' | sed 's/Intel(R)/Intel®/' | sed 's/Core(TM)/Core™/' | sed 's/CPU //' | sed 's/  */ /g' | sed 's/ @ */ @/'"]
        stdout: SplitParser { onRead: data => root.cpu = data.trim() }
    }

    Process {
        id: getGpu
        running: false
        command: ["bash", "-c", `
            gpu=$(glxinfo 2>/dev/null | grep 'renderer string' | grep -o 'Intel(R) HD Graphics [0-9]\\{4\\}' | sed 's/Intel(R)/Intel®/')
            if [ -z "$gpu" ]; then
                gpu=$(lspci | grep -iE 'vga|3d|display' | head -1 | sed -E '
                    s/.*: //;
                    s/\\(rev [0-9a-f]+\\)//;
                    s/Advanced Micro Devices, Inc\\. \\[AMD\\/ATI\\]//;
                    s/NVIDIA Corporation//;
                    s/Intel Corporation//;
                    s/.*\\[([^]]+)\\]$/\\1/;
                    s/^ *//;
                    s/ *$//
                ')
            fi
            echo "$gpu"
        `]
        stdout: SplitParser { onRead: data => root.gpu = data.trim() }
    }

    Process {
        id: getMemory
        running: false
        command: ["bash", "-c", "LC_ALL=C free -h | awk '/^Mem:/ {print $3 \" / \" $2}'"]
        stdout: SplitParser { onRead: data => root.memory = data.trim() }
    }

    Process {
        id: getDisk
        running: false
        command: ["bash", "-c", "df -h / | awk 'NR==2 {print $3 \" / \" $2}'"]
        stdout: SplitParser { onRead: data => root.disk = data.trim() }
    }


    Process {
        id: getPackages
        running: false
        command: ["bash", "-c", "pacman_count=$(pacman -Q | wc -l); flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo 0); if [ \"$flatpak_count\" -gt 0 ]; then echo \"$pacman_count pacman, $flatpak_count fp\"; else echo \"$pacman_count pacman\"; fi"]
        stdout: SplitParser { onRead: data => root.packages = data.trim() }
    }

    Process {
        id: getInstallAge
        running: false
        command: ["bash", "-c", "install_sec=$(stat -c %W /); if [ \"$install_sec\" -le 0 ]; then install_sec=$(stat -c %Y /); fi; now_sec=$(date +%s); age_sec=$((now_sec - install_sec)); days=$((age_sec / 86400)); echo \"$days days\""]
        stdout: SplitParser { onRead: data => root.installAge = data.trim() }
    }
}