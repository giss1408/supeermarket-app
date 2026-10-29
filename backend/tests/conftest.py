import pytest
from django.core.cache import cache


@pytest.fixture(autouse=True)
def _clear_cache():
    """Throttle counters live in the cache; never let them leak between tests."""
    cache.clear()
    yield
    cache.clear()


@pytest.fixture(autouse=True)
def _isolated_media(settings, tmp_path):
    """Uploads never touch backend/media/: every test gets its own MEDIA_ROOT."""
    settings.MEDIA_ROOT = tmp_path / "media"
