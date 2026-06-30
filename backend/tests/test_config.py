from __future__ import annotations

from typing import Any, cast

import pytest

from app.core.config import Settings

DEFAULT_JWT_SECRET_KEY = "change-me-in-production-32-byte-minimum"


def test_non_local_env_rejects_default_jwt_secret() -> None:
    with pytest.raises(ValueError, match="JWT_SECRET_KEY"):
        _settings(
            app_env="dev",
            jwt_secret_key=DEFAULT_JWT_SECRET_KEY,
        )



def test_local_env_allows_local_defaults() -> None:
    settings = _settings(
        app_env="local",
        jwt_secret_key=DEFAULT_JWT_SECRET_KEY,
    )

    assert settings.app_env == "local"


def _settings(**kwargs: Any) -> Settings:
    settings_cls = cast(Any, Settings)
    return settings_cls(_env_file=None, **kwargs)
