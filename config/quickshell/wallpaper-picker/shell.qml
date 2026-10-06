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
    implicitHeight: 640
    color: "#161616"
    visible: true

    readonly property color bg:      "#161616"
    readonly property color panel:   "#1f1f1f"
    readonly property color line:    "#3a3a3a"
    readonly property color dim:     "#8a8a8a"
    readonly property color fg:      "#e6e6e6"

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateFile: home + "/.config/quickshell/wallpaper-picker/last-dir"
    property string wallDir: home + "/Pictures/backgrounds"
    property string current: ""
    property bool closeOnPick: false

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

        Column {
            anchors.fill: parent
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
                                color: "#cc161616"
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
                text: folderModel.count + " images   |   click = set image as backgroud   |   Esc = close   | backend = feh "
                color: win.dim
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
