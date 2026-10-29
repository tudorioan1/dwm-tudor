import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: win
    title: "wallpaper-picker"
    implicitWidth: 920
    implicitHeight: 672
    color: bg
    visible: true

    // Palette. The values below are the plain black look, used when no theme file is found.
    // applyTheme() replaces them with colours derived from the active dwm theme (polybar's
    // colors.ini, written by theme-apply.sh) and keeps them in sync when the theme changes.
    property color bg:      "#0f0f0f"
    property color panel:   "#181818"
    property color line:    "#333333"
    property color dim:     "#8a8a8a"
    property color fg:      "#e6e6e6"

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateFile: home + "/.config/quickshell/wallpaper-picker/last-dir"
    property string wallDir: home + "/Pictures/backgrounds"
    property string current: ""
    property bool closeOnPick: false

    function hexColor(h) {
        return Qt.rgba(parseInt(h.substr(1, 2), 16) / 255,
                       parseInt(h.substr(3, 2), 16) / 255,
                       parseInt(h.substr(5, 2), 16) / 255, 1)
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    // Build the palette from polybar's colors.ini. The window background is a little darker
    // than the bar; panels (inputs, thumbnails) stand out from it: between the bar and its alt
    // colour on dark themes, the bar colour itself on light ones. If the file is missing
    // or half-written (theme-apply.sh is mid-write) the current look is kept.
    function applyTheme(text) {
        const found = {}
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^\s*(bg|fg|bg-alt|fg-alt)\s*=\s*(#[0-9A-Fa-f]{6})(?![0-9A-Fa-f])/)
            if (m) found[m[1]] = m[2]
        }
        if (!found["bg"] || !found["fg"] || !found["bg-alt"] || !found["fg-alt"]) return

        const tbg = hexColor(found["bg"])
        const dark = (0.299 * tbg.r + 0.587 * tbg.g + 0.114 * tbg.b) < 0.5
        bg = Qt.darker(tbg, dark ? 1.35 : 1.05)
        panel = dark ? mix(tbg, hexColor(found["bg-alt"]), 0.5) : tbg
        dim = hexColor(found["fg-alt"])
        fg = hexColor(found["fg"])
        line = mix(panel, dim, 0.35)
    }

    function expand(p) {
        p = p.trim()
        if (p === "~") p = home
        else if (p.startsWith("~/")) p = home + p.slice(1)
        if (p.length > 1 && p.endsWith("/")) p = p.slice(0, -1)
        return p
    }

    function applyDir(p) {
        wallDir = expand(p)
        pathField.text = wallDir
        store.setText(wallDir)
    }

    function setWall(path) {
        feh.running = false
        feh.command = ["feh", "--bg-fill", path]
        feh.running = true
        current = path
        if (closeOnPick) Qt.quit()
    }

    FileView {
        id: store
        path: win.stateFile
        blockLoading: true
    }

    // Follow the dwm theme: re-read colors.ini whenever theme-apply.sh rewrites it
    FileView {
        id: themeColors
        path: win.home + "/.config/polybar/themes/minimal/colors.ini"
        watchChanges: true
        onFileChanged: themeColors.reload()
        onLoaded: win.applyTheme(themeColors.text())
    }

    Process { id: feh }

    Component.onCompleted: {
        try {
            const t = store.text().trim()
            if (t.length > 0) wallDir = t
        } catch (e) {}
        pathField.text = wallDir
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    Rectangle {
        anchors.fill: parent
        color: win.bg

        // Title strip, with the close button in the top-right corner
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "DWM Wallpaper Picker"
                color: win.dim
                font.pixelSize: 12
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: win.line
            }

            Rectangle {
                id: closeBtn
                anchors.top: parent.top
                anchors.right: parent.right
                width: 40
                height: parent.height - 1
                color: closeArea.containsMouse ? win.fg : "transparent"

                // The X is drawn with two rotated bars, so it does not depend on any font
                Item {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 1.5
                        rotation: 45
                        antialiasing: true
                        color: closeArea.containsMouse ? win.bg : win.fg
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: 1.5
                        rotation: -45
                        antialiasing: true
                        color: closeArea.containsMouse ? win.bg : win.fg
                    }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }
        }

        Column {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 12

            Row {
                width: parent.width
                height: 38
                spacing: 8

                Text {
                    text: "Folder"
                    color: win.dim
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                    id: pathField
                    width: parent.width - 60 - 90 - 16
                    height: parent.height
                    color: win.fg
                    selectionColor: win.fg
                    selectedTextColor: win.bg
                    font.pixelSize: 13
                    leftPadding: 10
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "~/Pictures/backgrounds"
                    placeholderTextColor: win.dim
                    background: Rectangle {
                        color: win.panel
                        border.width: 1
                        border.color: pathField.activeFocus ? win.fg : win.line
                    }
                    onAccepted: win.applyDir(text)
                }

                Rectangle {
                    width: 90
                    height: parent.height
                    color: applyArea.containsMouse ? win.fg : win.panel
                    border.width: 1
                    border.color: win.line
                    Text {
                        anchors.centerIn: parent
                        text: "Apply"
                        font.pixelSize: 13
                        color: applyArea.containsMouse ? win.bg : win.fg
                    }
                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: win.applyDir(pathField.text)
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 38 - 12 - 22 - 12

                FolderListModel {
                    id: folderModel
                    folder: "file://" + win.wallDir
                    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
                    caseSensitive: false
                    showDirs: false
                    sortField: FolderListModel.Name
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    model: folderModel
                    readonly property int columns: 4
                    cellWidth: Math.floor(width / columns)
                    cellHeight: Math.round(cellWidth * 0.66)
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        contentItem: Rectangle { implicitWidth: 6; color: win.dim }
                        background: Rectangle { color: "transparent" }
                    }

                    delegate: Item {
                        id: cell
                        required property string fileName
                        required property string filePath
                        required property url fileUrl
                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property bool hovered: ma.containsMouse
                        readonly property bool active: win.current === cell.filePath

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            color: win.panel
                            border.width: (cell.hovered || cell.active) ? 2 : 1
                            border.color: cell.active ? win.fg : (cell.hovered ? win.dim : win.line)

                            Image {
                                id: img
                                anchors.fill: parent
                                anchors.margins: 2
                                source: cell.fileUrl
                                sourceSize.width: 420
                                sourceSize.height: 280
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: img
                                source: img
                                saturation: 0.0
                                brightness: cell.hovered ? 0.0 : 0.0
                            }

                            Rectangle {
                                anchors.left: img.left
                                anchors.right: img.right
                                anchors.bottom: img.bottom
                                height: 22
                                color: Qt.rgba(win.bg.r, win.bg.g, win.bg.b, 0.8)
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    text: cell.fileName
                                    elide: Text.ElideMiddle
                                    color: win.fg
                                    font.pixelSize: 11
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.setWall(cell.filePath)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: folderModel.count === 0
                    text: "No image found in " + win.wallDir
                    color: win.dim
                    font.pixelSize: 14
                }
            }

            Text {
                width: parent.width
                height: 22
                text: folderModel.count + " images   |   backend = feh "
                color: win.dim
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
