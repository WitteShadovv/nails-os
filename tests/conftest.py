"""Mock libcalamares so the installer module can be imported outside Calamares."""

import sys
import types
import importlib.util
import os
from unittest.mock import MagicMock

import pytest


class _FakeGlobalStorage(dict):
    """Dict-like object that also supports gs.value(key) as Calamares uses."""

    def value(self, key):
        return self.get(key)


def _install_libcalamares_mock():
    """Create and register a fake libcalamares in sys.modules."""
    mod = types.ModuleType("libcalamares")
    utils = types.ModuleType("libcalamares.utils")

    # Logging helpers
    utils.debug = MagicMock()
    utils.warning = MagicMock()
    utils.error = MagicMock()
    utils.gettext_path = MagicMock(return_value="/dev/null")
    utils.gettext_languages = MagicMock(return_value=[])

    mod.utils = utils

    # globalstorage
    mod.globalstorage = _FakeGlobalStorage()

    # job
    job = MagicMock()
    job.configuration = {}
    mod.job = job

    sys.modules["libcalamares"] = mod
    sys.modules["libcalamares.utils"] = utils
    return mod


# Install once at import time so that `import libcalamares` works everywhere.
_libcal = _install_libcalamares_mock()


def _import_main():
    """Import the installer main module, patching syntax errors if needed."""
    path = os.path.join(
        os.path.dirname(__file__),
        "..",
        "nix-config",
        "hosts",
        "nails-os-iso",
        "calamares",
        "modules",
        "nails-os",
        "main.py",
    )
    path = os.path.realpath(path)

    with open(path, "r", encoding="utf-8") as f:
        source = f.read()

    code = compile(source, path, "exec")
    mod = types.ModuleType("nails_os_main")
    mod.__file__ = path
    exec(code, mod.__dict__)
    return mod


main = _import_main()


@pytest.fixture
def gs():
    """Return a fresh FakeGlobalStorage and install it into libcalamares."""
    store = _FakeGlobalStorage()
    _libcal.globalstorage = store
    return store


@pytest.fixture
def libcal():
    return _libcal
