#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# home-persistence-config — Calamares Python viewmodule.
#
# Shows a UI for the user to choose between selective home persistence
# (default) or full home persistence.
#
# The choice is written to /tmp/calamares-home-persistence-config.ini so the
# nails-os exec module can read it.

import configparser
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from nails_ui_common import *  # noqa: F401,F403,E402

_HOME_PERSISTENCE_CONFIG_PATH = "/tmp/calamares-home-persistence-config.ini"


def pretty_name():
    return "Home Persistence"


def _write_ini(full_persistence: bool) -> None:
    cp = configparser.ConfigParser()
    cp["General"] = {"fullPersistence": "true" if full_persistence else "false"}
    with open(_HOME_PERSISTENCE_CONFIG_PATH, "w") as fh:
        cp.write(fh)


class CollapsibleSection(QWidget):
    """A collapsible section widget."""

    def __init__(self, title, content, parent=None):
        super().__init__(parent)
        self._is_expanded = False

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        # Toggle button
        self._toggle_btn = QPushButton(f"▶ {title}")
        self._toggle_btn.setStyleSheet("""
            QPushButton {
                background-color: #1a1a2e;
                border: 1px solid #444466;
                border-radius: 4px;
                color: #7f5af0;
                padding: 6px 10px;
                text-align: left;
                font-size: 11px;
            }
            QPushButton:hover {
                background-color: #222244;
            }
        """)
        self._toggle_btn.clicked.connect(self._toggle)
        layout.addWidget(self._toggle_btn)

        # Content
        self._content = QLabel(content)
        self._content.setWordWrap(True)
        self._content.setStyleSheet("""
            background-color: #1a1a2e;
            border: 1px solid #444466;
            border-radius: 4px;
            padding: 8px;
            color: #aaaacc;
            font-size: 11px;
        """)
        self._content.setVisible(False)
        layout.addWidget(self._content)

        self._title = title

    def _toggle(self):
        self._is_expanded = not self._is_expanded
        self._content.setVisible(self._is_expanded)
        arrow = "▼" if self._is_expanded else "▶"
        self._toggle_btn.setText(f"{arrow} {self._title}")


class HomePersistenceConfigWidget(QWidget):
    def __init__(self):
        super().__init__()
        self._full_persistence = False  # Default: selective
        self._build_ui()
        # Write the default immediately
        _write_ini(False)

    def _build_ui(self):
        # Main layout with scroll area for long content
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setStyleSheet("background-color: transparent;")

        content_widget = QWidget()
        layout = QVBoxLayout(content_widget)
        layout.setContentsMargins(40, 20, 40, 20)
        layout.setSpacing(16)

        # Header
        header = QLabel("Home Persistence")
        header_font = QFont()
        header_font.setPointSize(18)
        header_font.setBold(True)
        header.setFont(header_font)
        header.setStyleSheet("color: #ffffff;")
        layout.addWidget(header)

        # Subtitle
        subtitle = QLabel(
            "Choose what data persists in your home directory between reboots:"
        )
        subtitle.setStyleSheet("color: #aaaacc; font-size: 13px;")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)

        layout.addSpacing(8)

        # Button group for radio buttons
        self._group = QButtonGroup(self)

        # --- Selective option (default/recommended) ---
        selective_card = OptionCard()
        selective_layout = QVBoxLayout(selective_card)
        selective_layout.setSpacing(8)

        selective_header_layout = QHBoxLayout()
        self._selective_radio = QRadioButton("Selective persistence")
        self._selective_radio.setChecked(True)
        self._selective_radio.setStyleSheet(
            "color: #e0e0e0; font-size: 14px; font-weight: bold;"
        )
        self._group.addButton(self._selective_radio, 1)
        selective_header_layout.addWidget(self._selective_radio)

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
        selective_header_layout.addWidget(recommended_label)
        selective_header_layout.addStretch()
        selective_layout.addLayout(selective_header_layout)

        selective_desc = QLabel(
            "Only your personal files and essential settings survive reboots. "
            "Browsing data, caches, and tracking artifacts are wiped every restart."
        )
        selective_desc.setWordWrap(True)
        selective_desc.setStyleSheet(
            "color: #aaaacc; font-size: 12px; margin-left: 24px;"
        )
        selective_layout.addWidget(selective_desc)

        # Collapsible details for selective
        selective_details = CollapsibleSection(
            "View details",
            "✓ Persisted:\n"
            "  Documents, Downloads, Music, Pictures, Videos, Desktop\n"
            "  GNOME settings, keyring (saved passwords)\n"
            "  SSH keys, GPG keys\n\n"
            "✗ Wiped every reboot:\n"
            "  Recent files list, file-manager thumbnails\n"
            "  File search index (Tracker), application caches\n"
            "  Browser profiles (history, cookies, sessions)",
        )
        selective_details.setStyleSheet("margin-left: 24px;")
        selective_layout.addWidget(selective_details)

        privacy_high = QLabel("Privacy: ●●● Maximum")
        privacy_high.setStyleSheet(
            "color: #2cb67d; font-size: 11px; margin-left: 24px;"
        )
        selective_layout.addWidget(privacy_high)

        layout.addWidget(selective_card)

        # --- Full option ---
        full_card = OptionCard()
        full_layout = QVBoxLayout(full_card)
        full_layout.setSpacing(8)

        full_header_layout = QHBoxLayout()
        self._full_radio = QRadioButton("Full home persistence")
        self._full_radio.setStyleSheet(
            "color: #e0e0e0; font-size: 14px; font-weight: bold;"
        )
        self._group.addButton(self._full_radio, 2)
        full_header_layout.addWidget(self._full_radio)
        full_header_layout.addStretch()
        full_layout.addLayout(full_header_layout)

        full_desc = QLabel(
            "Your entire home directory (/home/amnesia) is saved across reboots. "
            "More convenient, but forensic artifacts will accumulate."
        )
        full_desc.setWordWrap(True)
        full_desc.setStyleSheet("color: #aaaacc; font-size: 12px; margin-left: 24px;")
        full_layout.addWidget(full_desc)

        # Collapsible details for full
        full_details = CollapsibleSection(
            "View forensic risks",
            "The following artifacts will accumulate:\n\n"
            "• Recent files list — logs every file you open with timestamps\n"
            "• Thumbnail cache — retains image previews even after deletion\n"
            "• File search index — stores searchable copy of file contents\n"
            "• Application caches — may include browsing and usage history",
        )
        full_details.setStyleSheet("margin-left: 24px;")
        full_layout.addWidget(full_details)

        privacy_low = QLabel("Privacy: ●○○ Reduced")
        privacy_low.setStyleSheet("color: #e6a817; font-size: 11px; margin-left: 24px;")
        full_layout.addWidget(privacy_low)

        # Warning label (shown when full is selected)
        self._warning_label = QLabel(
            "⚠ Choose this only if you need apps that store important data outside "
            "the standard folders and you accept the privacy trade-off."
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
        full_layout.addWidget(self._warning_label)

        layout.addWidget(full_card)

        layout.addStretch()

        scroll.setWidget(content_widget)
        main_layout.addWidget(scroll)

        # Connect signals
        self._selective_radio.toggled.connect(self._on_toggle)

    def _on_toggle(self, checked: bool):
        self._full_persistence = not checked
        self._warning_label.setVisible(not checked)
        _write_ini(not checked)

    def full_persistence(self) -> bool:
        return self._full_persistence

    def set_full_persistence(self, full: bool):
        self._full_persistence = full
        _write_ini(full)


_widget = None


def create_widget():
    global _widget
    _widget = HomePersistenceConfigWidget()
    return _widget


def leaving():
    """Called by Calamares when the user moves to the next step."""
    if _widget is not None:
        _write_ini(_widget.full_persistence())
