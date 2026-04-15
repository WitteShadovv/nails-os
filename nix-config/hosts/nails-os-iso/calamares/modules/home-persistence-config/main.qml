import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import io.calamares.core 1.0

Page {
    id: homePersistenceConfigPage

    property bool fullPersistence: false

    onFullPersistenceChanged: {
        if (typeof calamaresWidget !== "undefined" && calamaresWidget !== null) {
            calamaresWidget.set_full_persistence(fullPersistence);
        }
    }

    Component.onCompleted: {
        fullPersistence = false;
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 30
        anchors.topMargin: 20
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: parent.parent.width - 60
            spacing: 16

            // Header
            Text {
                Layout.fillWidth: true
                text: qsTr("Home Persistence")
                font.pixelSize: 24
                font.bold: true
                color: "#ffffff"
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Choose what data persists in your home directory between reboots:")
                font.pixelSize: 14
                color: "#aaaacc"
                wrapMode: Text.WordWrap
            }

            Item { height: 4 }

            ButtonGroup {
                id: persistenceGroup
            }

            // --- Selective persistence (default/recommended) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: selectiveColumn.implicitHeight + 24
                color: selectiveRadio.checked ? "#2a2a4e" : "#222244"
                border.color: selectiveRadio.checked ? "#7f5af0" : "#444466"
                border.width: selectiveRadio.checked ? 2 : 1
                radius: 8

                MouseArea {
                    anchors.fill: parent
                    onClicked: selectiveRadio.checked = true
                    cursorShape: Qt.PointingHandCursor
                }

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    spacing: 16

                    // Icon
                    Image {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignTop
                        source: "../branding/nails-os/icons/persistence-selective.svg"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        id: selectiveColumn
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            spacing: 8

                            RadioButton {
                                id: selectiveRadio
                                checked: true
                                ButtonGroup.group: persistenceGroup
                                onCheckedChanged: {
                                    if (checked) {
                                        fullPersistence = false;
                                    }
                                }
                            }

                            Text {
                                text: qsTr("Selective persistence")
                                font.pixelSize: 16
                                font.bold: true
                                color: "#e0e0e0"
                            }

                            Rectangle {
                                width: recommendedLabel.width + 12
                                height: recommendedLabel.height + 4
                                color: "#7f5af0"
                                radius: 4

                                Text {
                                    id: recommendedLabel
                                    anchors.centerIn: parent
                                    text: qsTr("Recommended")
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Only your personal files and essential settings survive reboots. Browsing data, caches, and tracking artifacts are wiped every restart.")
                            font.pixelSize: 13
                            color: "#aaaacc"
                            wrapMode: Text.WordWrap
                        }

                        // Collapsible details
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.preferredHeight: selectiveDetailsExpanded ? selectiveDetailsContent.implicitHeight + 40 : 32
                            color: "#1a1a2e"
                            border.color: "#444466"
                            border.width: 1
                            radius: 4
                            clip: true

                            property bool selectiveDetailsExpanded: false

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: parent.selectiveDetailsExpanded = !parent.selectiveDetailsExpanded
                                cursorShape: Qt.PointingHandCursor
                            }

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 8

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: parent.parent.parent.selectiveDetailsExpanded ? "▼" : "▶"
                                        font.pixelSize: 10
                                        color: "#7f5af0"
                                    }
                                    Text {
                                        text: qsTr("View details")
                                        font.pixelSize: 12
                                        color: "#7f5af0"
                                    }
                                }

                                ColumnLayout {
                                    id: selectiveDetailsContent
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: parent.parent.selectiveDetailsExpanded
                                    opacity: parent.parent.selectiveDetailsExpanded ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("✓ Persisted:")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#2cb67d"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        text: "Documents, Downloads, Music, Pictures, Videos, Desktop\nGNOME settings, keyring (saved passwords)\nSSH keys, GPG keys"
                                        font.pixelSize: 11
                                        color: "#aaaacc"
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.3
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 4
                                        text: qsTr("✗ Wiped every reboot:")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#7f5af0"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        text: "Recent files list, file-manager thumbnails\nFile search index (Tracker), application caches\nBrowser profiles (history, cookies, sessions)"
                                        font.pixelSize: 11
                                        color: "#aaaacc"
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.3
                                    }
                                }
                            }
                        }

                        // Privacy indicator
                        RowLayout {
                            Layout.topMargin: 4
                            spacing: 6
                            Text {
                                text: qsTr("Privacy:")
                                font.pixelSize: 11
                                color: "#888899"
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#2cb67d"
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#2cb67d"
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#2cb67d"
                            }
                            Text {
                                text: qsTr("Maximum")
                                font.pixelSize: 11
                                color: "#2cb67d"
                            }
                        }
                    }
                }
            }

            // --- Full persistence option ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: fullColumn.implicitHeight + 24
                color: fullRadio.checked ? "#2a2a4e" : "#222244"
                border.color: fullRadio.checked ? "#e6a817" : "#444466"
                border.width: fullRadio.checked ? 2 : 1
                radius: 8

                MouseArea {
                    anchors.fill: parent
                    onClicked: fullRadio.checked = true
                    cursorShape: Qt.PointingHandCursor
                }

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    spacing: 16

                    // Icon
                    Image {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignTop
                        source: "../branding/nails-os/icons/persistence-full.svg"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        id: fullColumn
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            spacing: 8

                            RadioButton {
                                id: fullRadio
                                checked: false
                                ButtonGroup.group: persistenceGroup
                                onCheckedChanged: {
                                    if (checked) {
                                        fullPersistence = true;
                                    }
                                }
                            }

                            Text {
                                text: qsTr("Full home persistence")
                                font.pixelSize: 16
                                font.bold: true
                                color: "#e0e0e0"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Your entire home directory (/home/amnesia) is saved across reboots. More convenient, but forensic artifacts will accumulate.")
                            font.pixelSize: 13
                            color: "#aaaacc"
                            wrapMode: Text.WordWrap
                        }

                        // Collapsible details
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.preferredHeight: fullDetailsExpanded ? fullDetailsContent.implicitHeight + 40 : 32
                            color: "#1a1a2e"
                            border.color: "#444466"
                            border.width: 1
                            radius: 4
                            clip: true

                            property bool fullDetailsExpanded: false

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: parent.fullDetailsExpanded = !parent.fullDetailsExpanded
                                cursorShape: Qt.PointingHandCursor
                            }

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 8

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: parent.parent.parent.fullDetailsExpanded ? "▼" : "▶"
                                        font.pixelSize: 10
                                        color: "#e6a817"
                                    }
                                    Text {
                                        text: qsTr("View forensic risks")
                                        font.pixelSize: 12
                                        color: "#e6a817"
                                    }
                                }

                                ColumnLayout {
                                    id: fullDetailsContent
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: parent.parent.fullDetailsExpanded
                                    opacity: parent.parent.fullDetailsExpanded ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150 }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("The following artifacts will accumulate:")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#e6a817"
                                    }

                                    Repeater {
                                        model: [
                                            "Recent files list — logs every file you open with timestamps",
                                            "Thumbnail cache — retains image previews even after deletion",
                                            "File search index — stores searchable copy of file contents",
                                            "Application caches — may include browsing and usage history"
                                        ]
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 12
                                            text: "• " + modelData
                                            font.pixelSize: 11
                                            color: "#aaaacc"
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }

                        // Warning when selected
                        Rectangle {
                            visible: fullRadio.checked
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.preferredHeight: fullWarningText.implicitHeight + 12
                            color: "#3d2200"
                            border.color: "#e6a817"
                            border.width: 1
                            radius: 4

                            Text {
                                id: fullWarningText
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                text: qsTr("Choose this only if you need apps that store important data outside the standard folders and you accept the privacy trade-off.")
                                font.pixelSize: 12
                                color: "#e6a817"
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Privacy indicator
                        RowLayout {
                            Layout.topMargin: 4
                            spacing: 6
                            Text {
                                text: qsTr("Privacy:")
                                font.pixelSize: 11
                                color: "#888899"
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#e6a817"
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#444466"
                            }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#444466"
                            }
                            Text {
                                text: qsTr("Reduced")
                                font.pixelSize: 11
                                color: "#e6a817"
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: 20
            }
        }
    }
}
