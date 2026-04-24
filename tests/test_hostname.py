"""Tests for hostname sanitization logic (extracted from run()).

The hostname logic in main.py:
  raw_hostname = gs.value("hostname") or "nails-os"
  hostname = re.sub(r"[^a-zA-Z0-9\\-]", "-", raw_hostname)
  hostname = re.sub(r"-{2,}", "-", hostname).strip("-").lower()
  if not hostname:
      hostname = "nails-os"
"""

import re
import pytest


def sanitize_hostname(raw):
    """Replicate the hostname sanitization from main.py."""
    raw_hostname = raw or "nails-os"
    hostname = re.sub(r"[^a-zA-Z0-9\-]", "-", raw_hostname)
    hostname = re.sub(r"-{2,}", "-", hostname).strip("-").lower()
    if not hostname:
        hostname = "nails-os"
    return hostname


class TestHostnameBasic:
    def test_simple_valid(self):
        assert sanitize_hostname("myhost") == "myhost"

    def test_preserves_hyphens(self):
        assert sanitize_hostname("my-host") == "my-host"

    def test_preserves_digits(self):
        assert sanitize_hostname("host123") == "host123"

    def test_lowercased(self):
        assert sanitize_hostname("MyHost") == "myhost"


class TestHostnameSpecialChars:
    def test_dots_replaced(self):
        assert sanitize_hostname("my.host.name") == "my-host-name"

    def test_underscores_replaced(self):
        assert sanitize_hostname("my_host") == "my-host"

    def test_spaces_replaced(self):
        assert sanitize_hostname("my host") == "my-host"

    def test_at_sign_replaced(self):
        assert sanitize_hostname("user@host") == "user-host"

    def test_multiple_specials_collapsed(self):
        """Multiple consecutive special chars become one hyphen."""
        assert sanitize_hostname("a...b") == "a-b"

    def test_mixed_specials(self):
        assert sanitize_hostname("a._@b") == "a-b"


class TestHostnameEdgeCases:
    def test_empty_string(self):
        assert sanitize_hostname("") == "nails-os"

    def test_none(self):
        assert sanitize_hostname(None) == "nails-os"

    def test_only_special_chars(self):
        """All chars stripped → fallback."""
        assert sanitize_hostname("@#$%^&*()") == "nails-os"

    def test_leading_hyphens_stripped(self):
        assert sanitize_hostname("-myhost") == "myhost"

    def test_trailing_hyphens_stripped(self):
        assert sanitize_hostname("myhost-") == "myhost"

    def test_leading_and_trailing_hyphens(self):
        assert sanitize_hostname("--myhost--") == "myhost"

    def test_only_hyphens(self):
        assert sanitize_hostname("---") == "nails-os"

    def test_consecutive_hyphens_collapsed(self):
        assert sanitize_hostname("a--b") == "a-b"
        assert sanitize_hostname("a---b") == "a-b"
        assert sanitize_hostname("a----b") == "a-b"


class TestHostnameUnicode:
    def test_unicode_letters_replaced(self):
        assert sanitize_hostname("hôst") == "h-st"

    def test_full_unicode(self):
        assert sanitize_hostname("хост") == "nails-os"  # all replaced, all stripped

    def test_emoji(self):
        assert sanitize_hostname("🖥️server") == "server"

    def test_mixed_unicode_ascii(self):
        result = sanitize_hostname("my-сервер-01")
        assert result == "my-01"


class TestHostnameLong:
    def test_very_long_hostname(self):
        """The code doesn't truncate, but the result should still be valid."""
        result = sanitize_hostname("a" * 1000)
        assert result == "a" * 1000
        assert all(
            c in "abcdefghijklmnopqrstuvwxyz0123456789-" for c in result
        )  # pragma: allowlist secret
