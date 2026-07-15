"""ColorTrip 백엔드 진입점.

규약: docs/conventions/ (backend, api-design)
기능 스펙: docs/specs/000-quest/ · docs/specs/005-auth-member/ · docs/specs/010-journey/
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.staticfiles import StaticFiles

from app.auth.router import auth_router, users_router
from app.core.config import settings
from app.core.exceptions import register_exception_handlers
from app.core.response import Envelope, success
from app.journeys.router import router as journeys_router
from app.quests.router import progress_router
from app.quests.router import router as quests_router
from app.regions.router import router as regions_router
from app.trip_dna.router import router as trip_dna_router
from app.uploads.router import router as uploads_router

app = FastAPI(title="ColorTrip API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

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


# --- Swagger UI 글로벌 자물쇠(Authorize) 추가 및 Header 매핑 커스텀 스키마 ---
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title="ColorTrip API",
        version="0.1.0",
        routes=app.routes,
    )
    # 1. Bearer 인증 스키마 등록
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
        }
    }
    # 2. 모든 엔드포인트를 돌며 수동 'authorization' 헤더 입력을 글로벌 자물쇠 연동으로 치환
    for path in openapi_schema["paths"].values():
        for method in path.values():
            params = method.get("parameters", [])
            has_auth = False
            for param in list(params):
                if param.get("name") == "authorization" and param.get("in") == "header":
                    params.remove(param)  # 수동 입력 상자 제거
                    has_auth = True
            if has_auth:
                method["security"] = [{"BearerAuth": []}]  # 글로벌 자물쇠 자격증명 요구 설정

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi
# --------------------------------------------------------------------------

@app.get("/health", response_model=Envelope[dict])
async def health() -> Envelope[dict]:
    return success({"status": "ok"})
