#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# tor-config — Calamares Python viewmodule.
#
# Shows a UI for the user to choose whether all traffic should be routed
# through Tor (default) or go directly to the internet, and whether to
# use Tor bridges for censored networks.
#
# On leaving this step the following globalStorage keys are written:
#   nailsOsTorEnabled   (bool) – True if Tor routing is selected
#   nailsOsTorUseBridges (bool) – True if the "Use bridges" checkbox is ticked
#
import os
import sys

import libcalamares  # noqa: E402 – provided by the Calamares runtime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from nails_ui_common import *  # noqa: F401,F403,E402

try:
    from PySide6.QtGui import QPixmap  # noqa: E402
except ImportError:
    from PySide2.QtGui import QPixmap  # noqa: E402


def pretty_name():
    return "Network Routing"


class TorConfigWidget(QWidget):
    def __init__(self):
        super().__init__()
        self._tor_enabled = True  # Default: Tor enabled
        self._use_bridges = False  # Default: bridges checkbox unchecked
        self._build_ui()

    # ------------------------------------------------------------------
    # Methods called from QML via the calamaresWidget bridge
    # ------------------------------------------------------------------

    def set_tor_enabled(self, enabled: bool):
        """Called by QML when the user switches between Tor / Direct."""
        self._tor_enabled = enabled

    def set_use_bridges(self, enabled: bool):
        """Called by QML when the user ticks/unticks the bridges checkbox."""
        self._use_bridges = enabled

    # ------------------------------------------------------------------
    # Read-only accessors (used by leaving())
    # ------------------------------------------------------------------

    def tor_enabled(self) -> bool:
        return self._tor_enabled

    def use_bridges(self) -> bool:
        return self._use_bridges

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 20, 40, 20)
        layout.setSpacing(16)

        # Header
        header = QLabel("Network Routing")
        header_font = QFont()
        header_font.setPointSize(18)
        header_font.setBold(True)
        header.setFont(header_font)
        header.setStyleSheet("color: #ffffff;")
        layout.addWidget(header)

        # Subtitle
        subtitle = QLabel("Choose how this system connects to the internet:")
        subtitle.setStyleSheet("color: #aaaacc; font-size: 13px;")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)

        layout.addSpacing(8)

        # Button group for radio buttons
        self._group = QButtonGroup(self)

        # --- Tor option (default/recommended) ---
        tor_card = OptionCard()
        tor_layout = QVBoxLayout(tor_card)
        tor_layout.setSpacing(8)

        tor_header_layout = QHBoxLayout()
        self._tor_radio = QRadioButton("Route through Tor")
        self._tor_radio.setChecked(True)
        self._tor_radio.setStyleSheet(
            "color: #e0e0e0; font-size: 14px; font-weight: bold;"
        )
        self._group.addButton(self._tor_radio, 1)
        tor_header_layout.addWidget(self._tor_radio)

        recommended_label = QLabel("Recommended")
        recommended_label.setStyleSheet("""
            background-color: #7f5af0;
            color: white;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 10px;
            font-weight: bold;
        """)
        recommended_label.setFixedHeight(20)
        tor_header_layout.addWidget(recommended_label)
        tor_header_layout.addStretch()
        tor_layout.addLayout(tor_header_layout)

        tor_desc = QLabel(
            "All network traffic is transparently routed through the Tor anonymity "
            "network. DNS queries are resolved through Tor. This is the most private option."
        )
        tor_desc.setWordWrap(True)
        tor_desc.setStyleSheet("color: #aaaacc; font-size: 12px; margin-left: 24px;")
        tor_layout.addWidget(tor_desc)

        tor_features = QLabel("✓ IP hidden  ✓ DNS encrypted  ✓ ISP blind")
        tor_features.setStyleSheet(
            "color: #2cb67d; font-size: 11px; margin-left: 24px;"
        )
        tor_layout.addWidget(tor_features)

        layout.addWidget(tor_card)

        # --- Direct option ---
        direct_card = OptionCard()
        direct_layout = QVBoxLayout(direct_card)
        direct_layout.setSpacing(8)

        direct_header_layout = QHBoxLayout()
        self._direct_radio = QRadioButton("Direct connection")
        self._direct_radio.setStyleSheet(
            "color: #e0e0e0; font-size: 14px; font-weight: bold;"
        )
        self._group.addButton(self._direct_radio, 2)
        direct_header_layout.addWidget(self._direct_radio)
        direct_header_layout.addStretch()
        direct_layout.addLayout(direct_header_layout)

        direct_desc = QLabel(
            "Traffic goes directly to the internet without Tor. DNS is handled by "
            "Quad9 (9.9.9.9). Faster speeds, but reduced privacy."
        )
        direct_desc.setWordWrap(True)
        direct_desc.setStyleSheet("color: #aaaacc; font-size: 12px; margin-left: 24px;")
        direct_layout.addWidget(direct_desc)

        direct_features = QLabel("✗ IP exposed  ✓ Faster speeds  ✗ ISP can see")
        direct_features.setStyleSheet(
            "color: #e6a817; font-size: 11px; margin-left: 24px;"
        )
        direct_layout.addWidget(direct_features)

        # Warning label (shown when direct is selected)
        self._warning_label = QLabel(
            "⚠ Your real IP address will be visible to websites and your ISP can see which sites you connect to."
        )
        self._warning_label.setWordWrap(True)
        self._warning_label.setStyleSheet("""
            background-color: #3d2200;
            border: 1px solid #e6a817;
            border-radius: 4px;
            padding: 8px;
            color: #e6a817;
            font-size: 11px;
            margin-left: 24px;
            margin-top: 4px;
        """)
        self._warning_label.setVisible(False)
        direct_layout.addWidget(self._warning_label)

        layout.addWidget(direct_card)

        layout.addStretch()

        # Connect signals
        self._tor_radio.toggled.connect(self._on_toggle)

    def _on_toggle(self, checked: bool):
        self._tor_enabled = checked
        self._warning_label.setVisible(not checked)


_widget = None


def create_widget():
    global _widget
    _widget = TorConfigWidget()
    return _widget


def leaving():
    """Called by Calamares when the user moves to the next step.

    Persists both the Tor routing choice and the bridge preference into
    globalStorage so the nails-os exec module can read them when it
    generates the installed system's NixOS configuration.
    """
    if _widget is None:
        return

    tor_enabled = _widget.tor_enabled()
    use_bridges = _widget.use_bridges()

    libcalamares.utils.debug(
        "tor-config leaving: torEnabled={} useBridges={}".format(
            tor_enabled, use_bridges
        )
    )

    libcalamares.globalstorage.setValue("nailsOsTorEnabled", tor_enabled)
    libcalamares.globalstorage.setValue("nailsOsTorUseBridges", use_bridges)
