#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# nails_ui_common — Shared UI components for NAILS OS Calamares viewmodules.
#
# Provides the OptionCard widget, PySide6/PySide2 import compatibility,
# and shared styling constants used across the custom Calamares viewmodules.

import libcalamares

# ---------------------------------------------------------------------------
# PySide6 / PySide2 import compatibility
# ---------------------------------------------------------------------------
try:
    from PySide6.QtCore import Qt  # noqa: F401
    from PySide6.QtGui import QFont  # noqa: F401
    from PySide6.QtWidgets import (  # noqa: F401
        QWidget,
        QVBoxLayout,
        QHBoxLayout,
        QLabel,
        QRadioButton,
        QButtonGroup,
        QFrame,
        QSizePolicy,
        QPushButton,
        QScrollArea,
        QCheckBox,
    )

    PYSIDE_VERSION = 6
except ImportError:
    from PySide2.QtCore import Qt  # noqa: F401
    from PySide2.QtGui import QFont  # noqa: F401
    from PySide2.QtWidgets import (  # noqa: F401
        QWidget,
        QVBoxLayout,
        QHBoxLayout,
        QLabel,
        QRadioButton,
        QButtonGroup,
        QFrame,
        QSizePolicy,
        QPushButton,
        QScrollArea,
        QCheckBox,
    )

    PYSIDE_VERSION = 2

# ---------------------------------------------------------------------------
# Styling constants — NAILS OS dark theme
# ---------------------------------------------------------------------------
COLOR_BG_CARD = "#222244"
COLOR_BG_CARD_HOVER = "#2a2a4e"
COLOR_BORDER = "#444466"
COLOR_ACCENT = "#7f5af0"
COLOR_GREEN = "#2cb67d"
COLOR_WARN = "#e6a817"
COLOR_WARN_BG = "#3d2200"
COLOR_TEXT = "#e0e0e0"
COLOR_TEXT_MUTED = "#aaaacc"
COLOR_TEXT_DIM = "#888899"
COLOR_WHITE = "#ffffff"
COLOR_BG_DARK = "#1a1a2e"

OPTION_CARD_STYLESHEET = f"""
    OptionCard {{
        background-color: {COLOR_BG_CARD};
        border: 1px solid {COLOR_BORDER};
        border-radius: 8px;
        padding: 12px;
    }}
    OptionCard:hover {{
        background-color: {COLOR_BG_CARD_HOVER};
    }}
"""

RECOMMENDED_LABEL_STYLESHEET = f"""
    background-color: {COLOR_ACCENT};
    color: white;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: bold;
"""

WARNING_LABEL_STYLESHEET = f"""
    background-color: {COLOR_WARN_BG};
    border: 1px solid {COLOR_WARN};
    border-radius: 4px;
    padding: 8px;
    color: {COLOR_WARN};
    font-size: 11px;
    margin-left: 24px;
    margin-top: 4px;
"""


# ---------------------------------------------------------------------------
# Shared widgets
# ---------------------------------------------------------------------------
class OptionCard(QFrame):
    """A styled card widget for displaying an option."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.setStyleSheet(OPTION_CARD_STYLESHEET)


def make_header(text: str) -> QLabel:
    """Create a styled page header label."""
    header = QLabel(text)
    header_font = QFont()
    header_font.setPointSize(18)
    header_font.setBold(True)
    header.setFont(header_font)
    header.setStyleSheet(f"color: {COLOR_WHITE};")
    return header


def make_subtitle(text: str) -> QLabel:
    """Create a styled subtitle label."""
    subtitle = QLabel(text)
    subtitle.setStyleSheet(f"color: {COLOR_TEXT_MUTED}; font-size: 13px;")
    subtitle.setWordWrap(True)
    return subtitle


def make_recommended_label() -> QLabel:
    """Create a 'Recommended' badge label."""
    label = QLabel("Recommended")
    label.setStyleSheet(RECOMMENDED_LABEL_STYLESHEET)
    label.setFixedHeight(20)
    return label


def make_warning_label(text: str) -> QLabel:
    """Create a styled warning label (hidden by default)."""
    label = QLabel(text)
    label.setWordWrap(True)
    label.setStyleSheet(WARNING_LABEL_STYLESHEET)
    label.setVisible(False)
    return label


def make_privacy_label(level: str) -> QLabel:
    """Create an accessible privacy indicator label.

    *level* must be one of ``"high"``, ``"moderate"``, or ``"reduced"``.
    The label includes both a visual dot indicator **and** explicit text
    so that colour-blind users can distinguish privacy levels.
    """
    if level == "high":
        dots = "●●●"
        text = "High Privacy"
        color = COLOR_GREEN
    elif level == "moderate":
        dots = "●●○"
        text = "Moderate Privacy"
        color = COLOR_WARN
    else:  # "reduced"
        dots = "●○○"
        text = "Reduced Privacy"
        color = COLOR_WARN

    label = QLabel(f"Privacy: {dots} {text}")
    label.setStyleSheet(f"color: {color}; font-size: 11px; margin-left: 24px;")
    return label


# ---------------------------------------------------------------------------
# globalStorage helpers
# ---------------------------------------------------------------------------
def store_choice(key: str, value: str) -> None:
    """Write a value into Calamares globalStorage.

    The *key* should follow the ``packagechooser_packagechooser-<name>``
    convention so the nails-os exec module can find it.
    """
    libcalamares.globalstorage.insert(key, value)
