import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0

Page {
    id: torConfigPage

    property bool torEnabled: true

    // Persist the choice to a temp file so the Python install module can read it.
    // GlobalStorage.insert() is not callable from QML (not a slot/Q_INVOKABLE),
    // so we use Qt.labs.settings as a side-channel.
    Settings {
        id: torSettings
        fileName: "/tmp/calamares-tor-config.ini"
        property alias torEnabled: torConfigPage.torEnabled
    }

    Component.onCompleted: {
        torEnabled = true;
    }

    header: Item {
        height: 60

        Text {
            anchors.centerIn: parent
            text: qsTr("Network Routing")
            font.pixelSize: 22
            font.bold: true
            color: "#e0e0e0"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 40
            topMargin: 20
        }
        spacing: 20

        Text {
            Layout.fillWidth: true
            text: qsTr("Choose how this system connects to the internet:")
            font.pixelSize: 16
            color: "#e0e0e0"
            wrapMode: Text.WordWrap
        }

        ButtonGroup {
            id: routingGroup
        }

        // --- Tor routing (default) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: torColumn.implicitHeight + 30
            color: torRadio.checked ? "#2a2a4e" : "#222244"
            border.color: torRadio.checked ? "#7f5af0" : "#444466"
            border.width: torRadio.checked ? 2 : 1
            radius: 8

            ColumnLayout {
                id: torColumn
                anchors {
                    fill: parent
                    margins: 15
                }
                spacing: 6

                RadioButton {
                    id: torRadio
                    checked: true
                    ButtonGroup.group: routingGroup
                    text: qsTr("Route all traffic through Tor (recommended)")
                    font.pixelSize: 14
                    palette.windowText: "#e0e0e0"
                    onCheckedChanged: {
                        if (checked) {
                            torEnabled = true;
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    text: qsTr("All network traffic is transparently routed through the Tor anonymity network. DNS queries are resolved through Tor. This is the default and most private option.")
                    font.pixelSize: 12
                    color: "#aaaacc"
                    wrapMode: Text.WordWrap
                }
            }
        }

        // --- Direct / cleartext ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: directColumn.implicitHeight + 30
            color: directRadio.checked ? "#2a2a4e" : "#222244"
            border.color: directRadio.checked ? "#e6a817" : "#444466"
            border.width: directRadio.checked ? 2 : 1
            radius: 8

            ColumnLayout {
                id: directColumn
                anchors {
                    fill: parent
                    margins: 15
                }
                spacing: 6

                RadioButton {
                    id: directRadio
                    checked: false
                    ButtonGroup.group: routingGroup
                    text: qsTr("Use direct network connection (cleartext)")
                    font.pixelSize: 14
                    palette.windowText: "#e0e0e0"
                    onCheckedChanged: {
                        if (checked) {
                            torEnabled = false;
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    text: qsTr("Traffic goes directly to the internet without Tor. DNS is handled by Quad9 (9.9.9.9). Faster, but your IP address is visible to every site you visit.")
                    font.pixelSize: 12
                    color: "#aaaacc"
                    wrapMode: Text.WordWrap
                }

                // Warning shown when direct is selected
                Rectangle {
                    visible: directRadio.checked
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    Layout.topMargin: 4
                    Layout.preferredHeight: warningText.implicitHeight + 16
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
                        text: qsTr("Warning: Without Tor, your real IP address will be exposed to websites, your ISP can see which sites you visit, and network-level anonymity protections are disabled.")
                        font.pixelSize: 12
                        color: "#e6a817"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
