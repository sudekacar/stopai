"""Uygulamaya özgü hatalar.

Servis katmanı HTTP'den habersizdir: iş kuralı ihlallerini buradaki
hatalarla bildirir, `main.py` içindeki tek bir işleyici bunları HTTP
yanıtlarına çevirir.
"""

from __future__ import annotations


class AppError(Exception):
    """Kullanıcıya gösterilebilir hata tabanı."""

    status_code: int = 500
    error_code: str = "internal_error"
    detail: str = "Beklenmeyen bir hata oluştu."

    def __init__(self, detail: str | None = None) -> None:
        if detail is not None:
            self.detail = detail
        super().__init__(self.detail)


# --------------------------------------------------------------- Kimlik


class EmailAlreadyRegistered(AppError):
    status_code = 409
    error_code = "email_already_registered"
    detail = "Bu e-posta ile bir hesap zaten var."


class InvalidCredentials(AppError):
    status_code = 401
    error_code = "invalid_credentials"
    # Hesabın var olup olmadığını sızdırmamak için tek tip mesaj.
    detail = "E-posta veya şifre hatalı."


class NotAuthenticated(AppError):
    status_code = 401
    error_code = "not_authenticated"
    detail = "Bu işlem için giriş yapmanız gerekiyor."


class InvalidToken(AppError):
    status_code = 401
    error_code = "invalid_token"
    detail = "Oturum anahtarı geçersiz."


class TokenExpired(AppError):
    status_code = 401
    error_code = "token_expired"
    detail = "Oturum süresi doldu, lütfen tekrar giriş yapın."


class SubscriptionRequired(AppError):
    status_code = 403
    error_code = "subscription_required"
    detail = "Bu özellik AI Pro paketine dâhildir."


# ------------------------------------------------------------------- AI


class AiServiceError(AppError):
    status_code = 502
    error_code = "ai_request_failed"
    detail = "AI servisi isteği tamamlayamadı."


class AiUnavailable(AiServiceError):
    status_code = 503
    error_code = "ai_unavailable"
    detail = (
        "Yerel AI servisine (Ollama) ulaşılamıyor. Sunucuda `ollama serve` "
        "çalışıyor mu?"
    )


class AiTimeout(AiServiceError):
    status_code = 504
    error_code = "ai_timeout"
    detail = "AI yanıtı zaman aşımına uğradı, lütfen tekrar deneyin."


class AiModelMissing(AiServiceError):
    status_code = 503
    error_code = "ai_model_missing"
    detail = "İstenen model Ollama üzerinde yüklü değil."
