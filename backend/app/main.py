"""ColorTrip 백엔드 진입점.

규약: docs/conventions/ (backend, api-design)
기능 스펙: docs/specs/000-quest/
"""

from fastapi import FastAPI

from app.core.exceptions import register_exception_handlers
from app.core.response import Envelope, success
from app.quests.router import router as quests_router
from app.regions.router import router as regions_router

app = FastAPI(title="ColorTrip API", version="0.1.0")
register_exception_handlers(app)

app.include_router(regions_router, prefix="/api/v1")
app.include_router(quests_router, prefix="/api/v1")


@app.get("/health", response_model=Envelope[dict])
async def health() -> Envelope[dict]:
    return success({"status": "ok"})
