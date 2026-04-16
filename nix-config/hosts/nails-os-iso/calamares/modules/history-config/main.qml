import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import io.calamares.core 1.0

Page {
    id: historyConfigPage

    property bool historyEnabled: false

    Binding {
        target: historyConfigPage
        property: "historyEnabled"
        value: historyConfigPage.historyEnabled
        when: true
    }

    onHistoryEnabledChanged: {
        if (typeof calamaresWidget !== "undefined" && calamaresWidget !== null) {
            calamaresWidget.set_history_enabled(historyEnabled);
        }
    }

    Component.onCompleted: {
        historyEnabled = false;
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
            text: qsTr("Shell History")
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Choose whether your terminal commands are saved between sessions:")
            font.pixelSize: 14
            color: "#aaaacc"
            wrapMode: Text.WordWrap
        }

        Item { height: 8 }

        ButtonGroup {
            id: historyGroup
        }

        // --- Disabled option (default/recommended) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: disabledColumn.implicitHeight + 24
            color: disabledRadio.checked ? "#2a2a4e" : "#222244"
            border.color: disabledRadio.checked ? "#7f5af0" : "#444466"
            border.width: disabledRadio.checked ? 2 : 1
            radius: 8

            MouseArea {
                anchors.fill: parent
                onClicked: disabledRadio.checked = true
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
                    source: "../branding/nails-os/icons/history-disabled.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                ColumnLayout {
                    id: disabledColumn
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 8

                        RadioButton {
                            id: disabledRadio
                            checked: true
                            ButtonGroup.group: historyGroup
                            onCheckedChanged: {
                                if (checked) {
                                    historyEnabled = false;
                                }
                            }
                        }

                        Text {
                            text: qsTr("Disable shell history")
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
                        text: qsTr("Commands you type in the terminal leave no trace after your session ends. Your command history is never saved to disk.")
                        font.pixelSize: 13
                        color: "#aaaacc"
                        wrapMode: Text.WordWrap
                    }

                    // Privacy indicator
                    RowLayout {
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
                }
            }
        }

        // --- Enabled option ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: enabledColumn.implicitHeight + 24
            color: enabledRadio.checked ? "#2a2a4e" : "#222244"
            border.color: enabledRadio.checked ? "#e6a817" : "#444466"
            border.width: enabledRadio.checked ? 2 : 1
            radius: 8

            MouseArea {
                anchors.fill: parent
                onClicked: enabledRadio.checked = true
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
                    source: "../branding/nails-os/icons/history-enabled.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                ColumnLayout {
                    id: enabledColumn
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 8

                        RadioButton {
                            id: enabledRadio
                            checked: false
                            ButtonGroup.group: historyGroup
                            onCheckedChanged: {
                                if (checked) {
                                    historyEnabled = true;
                                }
                            }
                        }

                        Text {
                            text: qsTr("Enable shell history")
                            font.pixelSize: 16
                            font.bold: true
                            color: "#e0e0e0"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Shell commands are saved to history files (~/.bash_history, etc.). Convenient for recalling previous commands with the up arrow.")
                        font.pixelSize: 13
                        color: "#aaaacc"
                        wrapMode: Text.WordWrap
                    }

                    // Warning when selected
                    Rectangle {
                        visible: enabledRadio.checked
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
                            text: qsTr("Creates a persistent record of your terminal activity that could be recovered forensically.")
                            font.pixelSize: 12
                            color: "#e6a817"
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Privacy indicator
                    RowLayout {
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
