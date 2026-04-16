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
       Slide 2 — Tor Routing
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
                    text: "🌐  All Traffic Through Tor"
                    color: headingColor
                    font { pixelSize: 24; bold: true }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: bodyColor
                    font.pixelSize: 14
                    lineHeight: 1.5
                    text: "Every network connection from NAILS OS is transparently " +
                          "routed through the Tor network. You don't need to " +
                          "configure anything — it's automatic and enforced at " +
                          "the firewall level.\n\n" +
                          "• Your real IP address is never exposed to the sites you visit\n" +
                          "• DNS queries are resolved through Tor — no DNS leaks\n" +
                          "• Pluggable transports (obfs4 & Snowflake) help bypass censorship\n\n" +
                          "Use Tor Browser for web browsing. An \"Unsafe Browser\" is " +
                          "provided only for captive-portal login (hotel/airport WiFi)."
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
                    text: "NAILS OS boots from a fresh tmpfs root every time. " +
                          "When you shut down, most of the system is wiped clean.\n\n" +
                          "What persists between reboots:\n" +
                          "  ✓  Documents, Downloads, Music, Pictures, Videos, Desktop\n" +
                          "  ✓  SSH keys and GPG keys\n" +
                          "  ✓  GNOME settings and Wi-Fi passwords (keyring)\n\n" +
                          "What gets wiped:\n" +
                          "  ✗  Browser history, cache, and cookies\n" +
                          "  ✗  Temporary files and application state\n" +
                          "  ✗  Shell history (disabled by default)\n\n" +
                          "This means even if someone gains access to your device " +
                          "later, there is minimal trace of your activity."
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
                    text: "NAILS OS includes multiple layers of protection:\n\n" +
                          "• Full-disk encryption (LUKS) — your persisted data is " +
                          "encrypted at rest with the passphrase you chose\n\n" +
                          "• Shell history disabled — no record of commands you run\n\n" +
                          "• Hardened kernel — memory protections, disabled Firewire/" +
                          "Thunderbolt/USB4, slab hardening, and more\n\n" +
                          "• AppArmor — mandatory access control confines applications\n\n" +
                          "• No swap — sensitive data is never written to disk unencrypted\n\n" +
                          "• Firewall-enforced Tor — even if an application tries to " +
                          "bypass Tor, the firewall blocks it"
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
                    text: "After installation completes, your system will reboot. " +
                          "Here's what to expect:\n\n" +
                          "1. Enter your disk encryption passphrase at boot\n" +
                          "2. Log in — Tor connects automatically in the background\n" +
                          "3. A welcome guide will appear on first boot\n\n" +
                          "Key applications (find them in Activities):\n" +
                          "  • Tor Browser — anonymous web browsing\n" +
                          "  • Thunderbird — email with privacy in mind\n" +
                          "  • KeePassXC — password manager\n" +
                          "  • OnionShare — share files over Tor\n" +
                          "  • Onion Circuits — monitor your Tor connection\n" +
                          "  • LibreOffice, GIMP, Inkscape — productivity tools\n\n" +
                          "Stay safe. Stay private."
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
