/* NAILS OS Calamares slideshow — multi-slide with auto-advance */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        id: advanceTimer
        interval: 18000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    function onActivate() { advanceTimer.running = true }
    function onLeave()    { advanceTimer.running = false }

    /* ── colour palette ── */
    property color bgColor:       "#1e1e2e"
    property color headingColor:  "#e0e0e0"
    property color bodyColor:     "#b0b0c8"
    property color accentColor:   "#a0a0c0"
    property color dimColor:      "#707090"

    /* ================================================================
       Slide 1 — Welcome
       ================================================================ */
    Slide {
        Rectangle {
            anchors.fill: parent
            color: bgColor

            Column {
                anchors.centerIn: parent
                spacing: 24

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "logo.png"
                    width:  128; height: 128
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Installing NAILS OS…"
                    color: headingColor
                    font { pixelSize: 26; bold: true }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Privacy and security, by design."
                    color: accentColor
                    font.pixelSize: 15
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Your system will be ready in a few minutes.\n" +
                          "Sit back and learn what makes NAILS OS different."
                    color: dimColor
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    /* ================================================================
       Slide 2 — Network Modes
       ================================================================ */
    Slide {
        Rectangle {
            anchors.fill: parent
            color: bgColor

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.75
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🌐  Network Routing Choices"
                    color: headingColor
                    font { pixelSize: 24; bold: true }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: bodyColor
                    font.pixelSize: 14
                    lineHeight: 1.5
                    text: "Tor mode transparently routes TCP traffic and DNS through Tor, " +
                          "with built-in obfs4 and Snowflake bridges available when needed. " +
                          "Direct mode uses the normal clearnet instead, so Tor routing protections do not apply. " +
                          "Use Tor Browser for private browsing, and keep the Unsafe Browser only for captive-portal login."
                }
            }
        }
    }

    /* ================================================================
       Slide 3 — Impermanence
       ================================================================ */
    Slide {
        Rectangle {
            anchors.fill: parent
            color: bgColor

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.75
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🧹  Amnesic by Default"
                    color: headingColor
                    font { pixelSize: 24; bold: true }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: bodyColor
                    font.pixelSize: 14
                    lineHeight: 1.5
                    text: "NAILS OS starts from a fresh tmpfs root on every boot and wipes most system state at shutdown. " +
                          "By default, only common personal folders, SSH and GPG keys, GNOME settings, and the keyring persist; browser data, temporary files, and shell history do not. " +
                          "This reduces what remains on the device after use."
                }
            }
        }
    }

    /* ================================================================
       Slide 4 — Security Features
       ================================================================ */
    Slide {
        Rectangle {
            anchors.fill: parent
            color: bgColor

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.75
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🔒  Built-In Security"
                    color: headingColor
                    font { pixelSize: 24; bold: true }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: bodyColor
                    font.pixelSize: 14
                    lineHeight: 1.5
                    text: "Persisted data is protected by mandatory full-disk encryption, and shell history is disabled by default. " +
                          "The system also includes kernel hardening, AppArmor confinement, and no swap so sensitive data is less likely to leak to disk. " +
                          "In Tor mode, firewall rules enforce Tor routing and block direct bypass attempts."
                }
            }
        }
    }

    /* ================================================================
       Slide 5 — Getting Started
       ================================================================ */
    Slide {
        Rectangle {
            anchors.fill: parent
            color: bgColor

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.75
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🚀  Getting Started"
                    color: headingColor
                    font { pixelSize: 24; bold: true }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: bodyColor
                    font.pixelSize: 14
                    lineHeight: 1.5
                    text: "After installation, reboot, unlock the disk with your passphrase, and sign in normally. " +
                          "Your selected network mode starts automatically, and core apps like Tor Browser, Thunderbird, KeePassXC, OnionShare, and LibreOffice are available from Activities. " +
                          "Use Tor Browser for private browsing and keep the Unsafe Browser limited to captive-portal login."
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "nails-os.org"
                    color: dimColor
                    font.pixelSize: 12
                }
            }
        }
    }

    /* ── Slide navigation bar ── */
    Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 24 }
        spacing: 16

        Rectangle {
            width: 28; height: 28; radius: 14; color: "#404060"
            Text { anchors.centerIn: parent; text: "‹"; color: "#c0c0d0"; font.pixelSize: 18 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { advanceTimer.restart(); presentation.goToPreviousSlide() }
            }
        }

        Rectangle {
            width: 28; height: 28; radius: 14; color: "#404060"
            Text { anchors.centerIn: parent; text: "›"; color: "#c0c0d0"; font.pixelSize: 18 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { advanceTimer.restart(); presentation.goToNextSlide() }
            }
        }
    }
}
