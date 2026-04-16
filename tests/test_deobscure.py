"""Tests for _calamares_deobscure() — the KStringHandler::obscure XOR reversal.

This is security-critical: if deobscure is wrong the user's password will be
garbled, the hash will be wrong, and they'll be locked out post-install.
"""

import pytest
from tests.conftest import main

deobscure = main._calamares_deobscure


class TestDeobscureBasics:
    """Core behaviour of the XOR cipher."""

    def test_empty_string(self):
        assert deobscure("") == ""

    def test_self_inverse(self):
        """obscure(obscure(x)) == x — the algorithm is its own inverse."""
        for plaintext in ["password", "hunter2", "P@$$w0rd!", "abc123", "a"]:
            assert deobscure(deobscure(plaintext)) == plaintext

    def test_known_mapping_letter_a(self):
        """'a' (0x61) should map to chr(0x1001F - 0x61) = chr(0xFFBE)."""
        result = deobscure("a")
        assert result == chr(0x1001F - ord("a"))

    def test_known_mapping_tilde(self):
        """'~' (0x7E) should map to chr(0x1001F - 0x7E) = chr(0xFFA1)."""
        result = deobscure("~")
        assert result == chr(0x1001F - 0x7E)


class TestDeobscureBoundaryChars:
    """Characters with ord <= 0x21 must pass through unchanged."""

    @pytest.mark.parametrize("cp", range(0x22))
    def test_low_codepoints_unchanged(self, cp):
        ch = chr(cp)
        assert deobscure(ch) == ch

    def test_space_unchanged(self):
        """Space (0x20) is <= 0x21, must be unchanged."""
        assert deobscure(" ") == " "

    def test_exclamation_unchanged(self):
        """'!' (0x21) is <= 0x21, must be unchanged."""
        assert deobscure("!") == "!"

    def test_first_transformed_char(self):
        """'\"' (0x22) is > 0x21, must be transformed."""
        result = deobscure('"')
        assert result == chr(0x1001F - 0x22)
        assert result != '"'


class TestDeobscureUnicode:
    """Unicode and multi-byte strings."""

    def test_unicode_roundtrip(self):
        text = "pässwörd"
        assert deobscure(deobscure(text)) == text

    def test_emoji_raises_on_high_codepoints(self):
        """Emoji codepoints are > 0x1001F, so 0x1001F - cp < 0 → ValueError.
        This is a known limitation of the KStringHandler algorithm for
        characters outside the Basic Multilingual Plane."""
        with pytest.raises(ValueError):
            deobscure("🔐key")

    def test_cjk_roundtrip(self):
        text = "密码test"
        assert deobscure(deobscure(text)) == text

    def test_mixed_boundary_and_normal(self):
        """String with chars both <= 0x21 and > 0x21."""
        text = '\x00\x10 !"ab'
        result = deobscure(text)
        # First four chars unchanged, last three transformed
        assert result[:4] == "\x00\x10 !"
        assert result[4:] != '"ab'
        # Round-trip
        assert deobscure(result) == text


class TestDeobscureEdgeCases:
    def test_single_char(self):
        assert deobscure(deobscure("x")) == "x"

    def test_very_long_password(self):
        pwd = "A" * 10000
        assert deobscure(deobscure(pwd)) == pwd

    def test_all_printable_ascii_roundtrip(self):
        import string

        for ch in string.printable:
            assert deobscure(deobscure(ch)) == ch
