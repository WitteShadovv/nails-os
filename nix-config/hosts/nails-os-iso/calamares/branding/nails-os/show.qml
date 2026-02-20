/* NAILS OS Calamares slideshow */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function onActivate() {}
    function onLeave() {}

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 24

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "logo.png"
                width:  120
                height: 120
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  "Installing NAILS OS…"
                color: "#e0e0e0"
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  "Privacy and security, by design."
                color: "#a0a0c0"
                font.pixelSize: 14
            }
        }
    }
}
