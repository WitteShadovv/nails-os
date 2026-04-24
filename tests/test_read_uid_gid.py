"""Tests for read_uid_gid() — parses /etc/passwd in the target root.

Wrong UID/GID = wrong file ownership = security vulnerability (another user
could access the home directory, or the user can't access their own files).
"""

import os
import tempfile
import pytest
from tests.conftest import main

read_uid_gid = main.read_uid_gid


@pytest.fixture
def fake_root(tmp_path):
    """Create a fake root with an etc/passwd file."""
    etc = tmp_path / "etc"
    etc.mkdir()
    return tmp_path


def _write_passwd(fake_root, content):
    passwd = fake_root / "etc" / "passwd"
    passwd.write_text(content, encoding="utf-8")


class TestStandardParsing:
    def test_normal_user(self, fake_root):
        _write_passwd(
            fake_root, "amnesia:x:1000:1000:Amnesia User:/home/amnesia:/bin/bash\n"
        )
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid == "1000"
        assert gid == "1000"

    def test_root_user(self, fake_root):
        _write_passwd(fake_root, "root:x:0:0:root:/root:/bin/bash\n")
        uid, gid = read_uid_gid(str(fake_root), "root")
        assert uid == "0"
        assert gid == "0"

    def test_multiple_users(self, fake_root):
        content = (
            "root:x:0:0:root:/root:/bin/bash\n"
            "nobody:x:65534:65534:Nobody:/:/sbin/nologin\n"
            "amnesia:x:1000:1000::/home/amnesia:/bin/bash\n"
        )
        _write_passwd(fake_root, content)
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid == "1000"
        assert gid == "1000"

    def test_different_uid_gid(self, fake_root):
        _write_passwd(fake_root, "testuser:x:1001:1005:Test:/home/testuser:/bin/zsh\n")
        uid, gid = read_uid_gid(str(fake_root), "testuser")
        assert uid == "1001"
        assert gid == "1005"


class TestUserNotFound:
    def test_missing_user_returns_none_none(self, fake_root):
        _write_passwd(fake_root, "root:x:0:0:root:/root:/bin/bash\n")
        uid, gid = read_uid_gid(str(fake_root), "nonexistent")
        assert uid is None
        assert gid is None

    def test_empty_passwd(self, fake_root):
        _write_passwd(fake_root, "")
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid is None
        assert gid is None


class TestMalformedLines:
    def test_comment_lines_skipped(self, fake_root):
        content = "# This is a comment\namnesia:x:1000:1000::/home/amnesia:/bin/bash\n"
        _write_passwd(fake_root, content)
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid == "1000"
        assert gid == "1000"

    def test_too_few_fields(self, fake_root):
        """Line with fewer than 4 colon-separated fields → skipped."""
        content = "amnesia:x:1000\n"
        _write_passwd(fake_root, content)
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid is None
        assert gid is None

    def test_empty_lines_skipped(self, fake_root):
        content = "\n\namnesia:x:1000:1000::/home/amnesia:/bin/bash\n\n"
        _write_passwd(fake_root, content)
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid == "1000"
        assert gid == "1000"

    def test_partial_username_match(self, fake_root):
        """'amnesia2' should NOT match when looking for 'amnesia'."""
        content = "amnesia2:x:1001:1001::/home/amnesia2:/bin/bash\n"
        _write_passwd(fake_root, content)
        uid, gid = read_uid_gid(str(fake_root), "amnesia")
        assert uid is None
        assert gid is None

    def test_username_as_substring(self, fake_root):
        """Looking for 'am' should NOT match 'amnesia'."""
        content = "amnesia:x:1000:1000::/home/amnesia:/bin/bash\n"
        _write_passwd(fake_root, content)
        uid, gid = read_uid_gid(str(fake_root), "am")
        assert uid is None
        assert gid is None


class TestMissingFile:
    def test_no_passwd_file_returns_none(self, tmp_path):
        """No etc/passwd file → (None, None) without crashing."""
        uid, gid = read_uid_gid(str(tmp_path), "amnesia")
        assert uid is None
        assert gid is None

    def test_no_etc_dir_returns_none(self, tmp_path):
        uid, gid = read_uid_gid(str(tmp_path / "nonexistent"), "amnesia")
        assert uid is None
        assert gid is None
