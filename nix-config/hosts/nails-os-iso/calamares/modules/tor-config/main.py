#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# tor-config — Calamares Python viewmodule.
#
# Shows a UI for the user to choose whether all traffic should be routed
# through Tor (default) or go directly to the internet.
#
# The choice is written to /tmp/calamares-tor-config.ini as soon as the user
# makes a selection (and again on leave), so the nails-os exec module can read
# it regardless of whether a "leaving" callback is invoked.

import configparser

import libcalamares

try:
    from PySide6.QtCore import Qt
    from PySide6.QtWidgets import (
        QButtonGroup,
        QLabel,
        QRadioButton,
        QVBoxLayout,
        QWidget,
    )
except ImportError:
    from PySide2.QtCore import Qt
    from PySide2.QtWidgets import (
        QButtonGroup,
        QLabel,
        QRadioButton,
        QVBoxLayout,
        QWidget,
    )

_TOR_CONFIG_PATH = "/tmp/calamares-tor-config.ini"


def pretty_name():
    return "Network Routing"


def _write_ini(tor_enabled: bool) -> None:
    cp = configparser.ConfigParser()
    cp["General"] = {"torEnabled": "true" if tor_enabled else "false"}
    with open(_TOR_CONFIG_PATH, "w") as fh:
        cp.write(fh)


class TorConfigWidget(QWidget):
    def __init__(self):
        super().__init__()
        self._tor_enabled = True
        self._build_ui()
        # Write the default immediately so the install module gets a value
        # even if the user never changes the selection.
        _write_ini(True)

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 20, 40, 20)
        layout.setSpacing(16)

        heading = QLabel("Choose how this system connects to the internet:")
        heading.setWordWrap(True)
        layout.addWidget(heading)

        self._group = QButtonGroup(self)

        self._tor_radio = QRadioButton(
            "Route all traffic through Tor (recommended)"
        )
        self._tor_radio.setChecked(True)
        self._group.addButton(self._tor_radio, 1)
        layout.addWidget(self._tor_radio)

        tor_desc = QLabel(
            "    All network traffic is transparently routed through the Tor "
            "anonymity network. DNS queries are resolved through Tor. "
            "This is the default and most private option."
        )
        tor_desc.setWordWrap(True)
        layout.addWidget(tor_desc)

        layout.addSpacing(8)

        self._direct_radio = QRadioButton(
            "Use direct network connection (cleartext)"
        )
        self._group.addButton(self._direct_radio, 2)
        layout.addWidget(self._direct_radio)

        direct_desc = QLabel(
            "    Traffic goes directly to the internet without Tor. "
            "DNS is handled by Quad9 (9.9.9.9). Faster, but your IP address "
            "is visible to every site you visit."
        )
        direct_desc.setWordWrap(True)
        layout.addWidget(direct_desc)

        layout.addStretch()

        self._tor_radio.toggled.connect(self._on_toggle)

    def _on_toggle(self, checked: bool):
        self._tor_enabled = checked
        _write_ini(checked)

    def tor_enabled(self) -> bool:
        return self._tor_enabled


_widget = None


def create_widget():
    global _widget
    _widget = TorConfigWidget()
    return _widget


def leaving():
    """Called by Calamares when the user moves to the next step."""
    if _widget is not None:
        _write_ini(_widget.tor_enabled())
