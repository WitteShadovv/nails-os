#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# history-config — Calamares Python viewmodule.
#
# Shows a UI for the user to choose whether shell history should be
# disabled (default) or enabled.
#
# The choice is written to /tmp/calamares-history-config.ini so the
# nails-os exec module can read it.

import configparser
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from nails_ui_common import *  # noqa: F401,F403,E402

_HISTORY_CONFIG_PATH = "/tmp/calamares-history-config.ini"


def pretty_name():
    return "Shell History"


def _write_ini(history_enabled: bool) -> None:
    cp = configparser.ConfigParser()
    cp["General"] = {"historyEnabled": "true" if history_enabled else "false"}
    with open(_HISTORY_CONFIG_PATH, "w") as fh:
        cp.write(fh)


class HistoryConfigWidget(QWidget):
    def __init__(self):
        super().__init__()
        self._history_enabled = False  # Default: disabled
        self._build_ui()
        # Write the default immediately
        _write_ini(False)

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 20, 40, 20)
        layout.setSpacing(16)

        # Header
        header = QLabel("Shell History")
        header_font = QFont()
        header_font.setPointSize(18)
        header_font.setBold(True)
        header.setFont(header_font)
        header.setStyleSheet("color: #ffffff;")
        layout.addWidget(header)

        # Subtitle
        subtitle = QLabel(
            "Choose whether your terminal commands are saved between sessions:"
        )
        subtitle.setStyleSheet("color: #aaaacc; font-size: 13px;")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)

        layout.addSpacing(8)

        # Button group for radio buttons
        self._group = QButtonGroup(self)

        # --- Disabled option (default/recommended) ---
        disabled_card = OptionCard()
        disabled_layout = QVBoxLayout(disabled_card)
        disabled_layout.setSpacing(8)

        disabled_header_layout = QHBoxLayout()
        self._disabled_radio = QRadioButton("Disable shell history")
        self._disabled_radio.setChecked(True)
        self._disabled_radio.setStyleSheet(
            "color: #e0e0e0; font-size: 14px; font-weight: bold;"
        )
        self._group.addButton(self._disabled_radio, 1)
        disabled_header_layout.addWidget(self._disabled_radio)

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
        disabled_header_layout.addWidget(recommended_label)
        disabled_header_layout.addStretch()
        disabled_layout.addLayout(disabled_header_layout)

        disabled_desc = QLabel(
            "Commands you type in the terminal leave no trace after your session ends. "
            "Your command history is never saved to disk."
        )
        disabled_desc.setWordWrap(True)
        disabled_desc.setStyleSheet(
            "color: #aaaacc; font-size: 12px; margin-left: 24px;"
        )
        disabled_layout.addWidget(disabled_desc)

        privacy_high = QLabel("Privacy: ●●● Maximum")
        privacy_high.setStyleSheet(
            "color: #2cb67d; font-size: 11px; margin-left: 24px;"
        )
        disabled_layout.addWidget(privacy_high)

        layout.addWidget(disabled_card)

        # --- Enabled option ---
        enabled_card = OptionCard()
        enabled_layout = QVBoxLayout(enabled_card)
        enabled_layout.setSpacing(8)

        enabled_header_layout = QHBoxLayout()
        self._enabled_radio = QRadioButton("Enable shell history")
        self._enabled_radio.setStyleSheet(
            "color: #e0e0e0; font-size: 14px; font-weight: bold;"
        )
        self._group.addButton(self._enabled_radio, 2)
        enabled_header_layout.addWidget(self._enabled_radio)
        enabled_header_layout.addStretch()
        enabled_layout.addLayout(enabled_header_layout)

        enabled_desc = QLabel(
            "Shell commands are saved to history files (~/.bash_history, etc.). "
            "Convenient for recalling previous commands with the up arrow."
        )
        enabled_desc.setWordWrap(True)
        enabled_desc.setStyleSheet(
            "color: #aaaacc; font-size: 12px; margin-left: 24px;"
        )
        enabled_layout.addWidget(enabled_desc)

        privacy_low = QLabel("Privacy: ●○○ Reduced")
        privacy_low.setStyleSheet("color: #e6a817; font-size: 11px; margin-left: 24px;")
        enabled_layout.addWidget(privacy_low)

        # Warning label (shown when enabled is selected)
        self._warning_label = QLabel(
            "⚠ Creates a persistent record of your terminal activity that could be recovered forensically."
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
        enabled_layout.addWidget(self._warning_label)

        layout.addWidget(enabled_card)

        layout.addStretch()

        # Connect signals
        self._disabled_radio.toggled.connect(self._on_toggle)

    def _on_toggle(self, checked: bool):
        self._history_enabled = not checked
        self._warning_label.setVisible(not checked)
        _write_ini(not checked)

    def history_enabled(self) -> bool:
        return self._history_enabled

    def set_history_enabled(self, enabled: bool):
        self._history_enabled = enabled
        _write_ini(enabled)


_widget = None


def create_widget():
    global _widget
    _widget = HistoryConfigWidget()
    return _widget


def leaving():
    """Called by Calamares when the user moves to the next step."""
    if _widget is not None:
        _write_ini(_widget.history_enabled())
