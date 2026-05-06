"""Shared pytest fixtures for /diagram tests."""
import pathlib
import sys

import pytest

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import run  # noqa: E402


@pytest.fixture
def theme_editorial():
    return run.load_theme("editorial")


@pytest.fixture
def theme_technical():
    return run.load_theme("technical")
