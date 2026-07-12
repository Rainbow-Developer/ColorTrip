"""ColorTrip 백엔드 진입점.

규약: docs/conventions/ (backend, api-design)
기능 스펙: docs/specs/000-quest/ · docs/specs/005-auth-member/ · docs/specs/010-journey/
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.auth.router import auth_router, users_router
from app.core.config import settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import register_request_logging, setup_logging
from app.core.response import Envelope, success
from app.journeys.router import router as journeys_router
from app.quests.router import progress_router
from app.quests.router import router as quests_router
from app.regions.router import router as regions_router
from app.trip_dna.router import router as trip_dna_router
from app.uploads.router import router as uploads_router

setup_logging(app_env=settings.app_env, log_level=settings.log_level)

app = FastAPI(title="ColorTrip API", version="0.1.0")
register_request_logging(app)
register_exception_handlers(app)

app.include_router(auth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(regions_router, prefix="/api/v1")
app.include_router(quests_router, prefix="/api/v1")
app.include_router(progress_router, prefix="/api/v1")
app.include_router(journeys_router, prefix="/api/v1")
app.include_router(uploads_router, prefix="/api/v1")
app.include_router(trip_dna_router, prefix="/api/v1")

# 로컬 스토리지 사용 시 업로드 파일 정적 서빙 (GCS 사용 시 불필요)
if not settings.gcs_upload_bucket:
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")


@app.get("/health", response_model=Envelope[dict])
async def health() -> Envelope[dict]:
    return success({"status": "ok"})
