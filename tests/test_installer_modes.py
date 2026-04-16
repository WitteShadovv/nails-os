"""Focused tests for installer-written runtime mode snippets."""

from tests.conftest import main


class _GS:
    def __init__(self, values):
        self._values = values

    def value(self, key):
        return self._values.get(key)


def _captured_writes(monkeypatch):
    writes = {}

    def fake_write(path, content, mode=None):
        writes[path] = {"content": content, "mode": mode}

    monkeypatch.setattr(main, "write_file", fake_write)
    monkeypatch.setattr(main, "hash_password", lambda plaintext: "hashed:" + plaintext)
    return writes


def test_direct_mode_writes_only_network_override(tmp_path, monkeypatch):
    writes = _captured_writes(monkeypatch)
    gs = _GS(
        {
            "hostname": "nails",
            "password": "secret",
            "packagechooser_packagechooser-tor": "direct",
        }
    )

    result = main.write_user_config(gs, str(tmp_path), efi_mode=True)

    assert result == {"home_persistence_full": False}
    written_paths = set(writes)
    assert str(tmp_path / "hosts" / "nails-os" / "network-mode.nix") in written_paths
    assert (
        str(tmp_path / "hosts" / "nails-os" / "tor-bridges-mode.nix")
        not in written_paths
    )
    network_content = writes[str(tmp_path / "hosts" / "nails-os" / "network-mode.nix")][
        "content"
    ]
    assert "nailsOs.tor.enable = false;" in network_content


def test_tor_mode_keeps_runtime_default_without_bridge_override(tmp_path, monkeypatch):
    writes = _captured_writes(monkeypatch)
    gs = _GS(
        {
            "hostname": "nails",
            "password": "secret",
            "packagechooser_packagechooser-tor": "tor",
        }
    )

    result = main.write_user_config(gs, str(tmp_path), efi_mode=True)

    assert result == {"home_persistence_full": False}
    written_paths = set(writes)
    assert (
        str(tmp_path / "hosts" / "nails-os" / "network-mode.nix") not in written_paths
    )
    assert (
        str(tmp_path / "hosts" / "nails-os" / "tor-bridges-mode.nix")
        not in written_paths
    )


def test_installer_ignores_custom_username_input(tmp_path, monkeypatch):
    writes = _captured_writes(monkeypatch)
    gs = _GS(
        {
            "hostname": "nails",
            "username": "custom-user",
            "fullname": "Custom User",
            "password": "secret",
        }
    )

    result = main.write_user_config(gs, str(tmp_path), efi_mode=True)

    assert result == {"home_persistence_full": False}
    secrets_content = writes[str(tmp_path / "modules" / "secrets.nix")]["content"]
    assert "users.users.amnesia.hashedPasswordFile" in secrets_content
    assert "custom-user" not in secrets_content
    assert str(tmp_path / "modules" / "secrets" / "amnesia.passwd") in writes


def test_tor_mode_removes_stale_direct_and_bridge_overrides(tmp_path, monkeypatch):
    writes = _captured_writes(monkeypatch)
    network_mode = tmp_path / "hosts" / "nails-os" / "network-mode.nix"
    tor_bridges_mode = tmp_path / "hosts" / "nails-os" / "tor-bridges-mode.nix"
    network_mode.parent.mkdir(parents=True)
    network_mode.write_text("stale direct override", encoding="utf-8")
    tor_bridges_mode.write_text("stale bridge override", encoding="utf-8")

    gs = _GS(
        {
            "hostname": "nails",
            "password": "secret",
            "packagechooser_packagechooser-tor": "tor",
        }
    )

    result = main.write_user_config(gs, str(tmp_path), efi_mode=True)

    assert result == {"home_persistence_full": False}
    assert not network_mode.exists()
    assert not tor_bridges_mode.exists()
    assert str(network_mode) not in writes
    assert str(tor_bridges_mode) not in writes
