"""v1 API yönlendiricisi."""

from fastapi import APIRouter

from app.api.routes import ai, auth, results

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(results.router)
api_router.include_router(ai.router)
