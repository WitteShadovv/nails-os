import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import io.calamares.core 1.0

Page {
    id: torConfigPage

    property bool torEnabled: true
    property bool useBridges: false

    onTorEnabledChanged: {
        if (typeof calamaresWidget !== "undefined" && calamaresWidget !== null) {
            calamaresWidget.set_tor_enabled(torEnabled);
        }
    }

    onUseBridgesChanged: {
        if (typeof calamaresWidget !== "undefined" && calamaresWidget !== null) {
            calamaresWidget.set_use_bridges(useBridges);
        }
    }

    Component.onCompleted: {
        torEnabled = true;
        useBridges = false;
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 30
            topMargin: 20
        }
        spacing: 16

        // Header
        Text {
            Layout.fillWidth: true
            text: qsTr("Network Routing")
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Choose how this system connects to the internet:")
            font.pixelSize: 14
            color: "#aaaacc"
            wrapMode: Text.WordWrap
        }

        Item { height: 8 }

        ButtonGroup {
            id: routingGroup
        }

        // --- Tor routing (default/recommended) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: torColumn.implicitHeight + 24
            color: torRadio.checked ? "#2a2a4e" : "#222244"
            border.color: torRadio.checked ? "#7f5af0" : "#444466"
            border.width: torRadio.checked ? 2 : 1
            radius: 8

            MouseArea {
                anchors.fill: parent
                onClicked: torRadio.checked = true
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
                    source: "../branding/nails-os/icons/tor-onion.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                ColumnLayout {
                    id: torColumn
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 8

                        RadioButton {
                            id: torRadio
                            checked: true
                            ButtonGroup.group: routingGroup
                            onCheckedChanged: {
                                if (checked) {
                                    torEnabled = true;
                                }
                            }
                        }

                        Text {
                            text: qsTr("Route through Tor")
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
                        text: qsTr("All network traffic is transparently routed through the Tor anonymity network. DNS queries are resolved through Tor. This is the most private option.")
                        font.pixelSize: 13
                        color: "#aaaacc"
                        wrapMode: Text.WordWrap
                    }

                    // Features list
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 16

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "✓"
                                font.pixelSize: 12
                                color: "#2cb67d"
                            }
                            Text {
                                text: qsTr("IP hidden")
                                font.pixelSize: 11
                                color: "#aaaacc"
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "✓"
                                font.pixelSize: 12
                                color: "#2cb67d"
                            }
                            Text {
                                text: qsTr("DNS encrypted")
                                font.pixelSize: 11
                                color: "#aaaacc"
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "✓"
                                font.pixelSize: 12
                                color: "#2cb67d"
                            }
                            Text {
                                text: qsTr("ISP blind")
                                font.pixelSize: 11
                                color: "#aaaacc"
                            }
                        }
                    }

                    // Privacy indicator with accessible text label
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
                            text: qsTr("High Privacy")
                            font.pixelSize: 11
                            color: "#2cb67d"
                        }
                    }

                    // --- Tor bridges toggle ---
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 8
                        visible: torRadio.checked

                        CheckBox {
                            id: bridgesCheckBox
                            checked: false
                            onCheckedChanged: {
                                useBridges = checked;
                            }
                        }

                        ColumnLayout {
                            spacing: 4

                            Text {
                                text: qsTr("Use Tor bridges (for censored networks)")
                                font.pixelSize: 12
                                font.bold: true
                                color: "#e0e0e0"
                            }

                            Text {
                                visible: bridgesCheckBox.checked
                                text: qsTr("Bridges disguise your Tor traffic so it is harder to detect. Enable this if Tor is blocked in your country or network.")
                                font.pixelSize: 11
                                color: "#aaaacc"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // --- Direct / cleartext ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: directColumn.implicitHeight + 24
            color: directRadio.checked ? "#2a2a4e" : "#222244"
            border.color: directRadio.checked ? "#e6a817" : "#444466"
            border.width: directRadio.checked ? 2 : 1
            radius: 8

            MouseArea {
                anchors.fill: parent
                onClicked: directRadio.checked = true
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
                    source: "../branding/nails-os/icons/direct-globe.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                ColumnLayout {
                    id: directColumn
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 8

                        RadioButton {
                            id: directRadio
                            checked: false
                            ButtonGroup.group: routingGroup
                            onCheckedChanged: {
                                if (checked) {
                                    torEnabled = false;
                                }
                            }
                        }

                        Text {
                            text: qsTr("Direct connection")
                            font.pixelSize: 16
                            font.bold: true
                            color: "#e0e0e0"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Traffic goes directly to the internet without Tor. DNS is handled by Quad9 (9.9.9.9). Faster speeds, but reduced privacy.")
                        font.pixelSize: 13
                        color: "#aaaacc"
                        wrapMode: Text.WordWrap
                    }

                    // Features list
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 16

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "✗"
                                font.pixelSize: 12
                                color: "#e6a817"
                            }
                            Text {
                                text: qsTr("IP exposed")
                                font.pixelSize: 11
                                color: "#aaaacc"
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "✓"
                                font.pixelSize: 12
                                color: "#2cb67d"
                            }
                            Text {
                                text: qsTr("Faster speeds")
                                font.pixelSize: 11
                                color: "#aaaacc"
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "✗"
                                font.pixelSize: 12
                                color: "#e6a817"
                            }
                            Text {
                                text: qsTr("ISP can see")
                                font.pixelSize: 11
                                color: "#aaaacc"
                            }
                        }
                    }

                    // Warning when selected
                    Rectangle {
                        visible: directRadio.checked
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.preferredHeight: warningText.implicitHeight + 12
                        color: "#3d2200"
                        border.color: "#e6a817"
                        border.width: 1
                        radius: 4

                        Text {
                            id: warningText
                            anchors {
                                fill: parent
                                margins: 8
                            }
                            text: qsTr("Your real IP address will be visible to websites and your ISP can see which sites you connect to.")
                            font.pixelSize: 12
                            color: "#e6a817"
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Privacy indicator with accessible text label
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
                            text: qsTr("Reduced Privacy")
                            font.pixelSize: 11
                            color: "#e6a817"
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
