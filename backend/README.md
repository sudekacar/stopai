# Stop! AI Ehliyet Koçu — Backend

Mobil uygulamanın sunucu tarafı: FastAPI, SQLite (async SQLAlchemy 2.0),
JWT kimlik doğrulama ve yerel Ollama (Llama 3) üzerinden çalışan AI koç.

## Hızlı başlangıç

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows
# source .venv/bin/activate     # macOS / Linux

pip install -r requirements-dev.txt
copy .env.example .env          # cp .env.example .env
```

`.env` içinde en az `DATABASE_URL` ve `JWT_SECRET_KEY` değerlerini doldurun.
Anahtar üretmek için:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

### Veritabanı

Varsayılan `DATABASE_URL` yerel bir SQLite dosyasıdır (`./test.db`).
Şemayı Alembic ile kurun; dosya yoksa oluşturulur:

```bash
alembic upgrade head
```

### Sunucuyu başlatma

```bash
uvicorn app.main:app --reload --port 8000
```

- Etkileşimli dokümantasyon: http://localhost:8000/docs
- Canlılık: `GET /health`, veritabanı hazırlığı: `GET /health/ready`

### Ollama (Llama 3)

AI uçları sunucuyla **aynı makinede** çalışan Ollama'ya bağlanır; veri
dışarı çıkmaz.

```bash
ollama serve
ollama pull llama3        # metin soruları
ollama pull llava         # araç parçası fotoğrafları (görme yeteneği)
```

`GET /api/v1/ai/health` Ollama'nın ayakta olup olmadığını ve modelin yüklü
olup olmadığını söyler; sorun varsa hata fırlatmak yerine durumu bildirir.

## Uç noktalar

Tümü `/api/v1` önekiyle sunulur. 🔒 işaretli uçlar
`Authorization: Bearer <access_token>` başlığı ister.

| Metot | Yol | Açıklama |
| --- | --- | --- |
| POST | `/auth/register` | E-posta + şifre ile kayıt, JWT döner |
| POST | `/auth/login` | Giriş, JWT döner |
| GET | `/auth/me` 🔒 | Oturumu açık kullanıcı |
| PATCH | `/auth/me/subscription` 🔒 | Paket durumunu güncelle |
| POST | `/results` 🔒 | Çözülen testin skorunu kaydet |
| GET | `/results` 🔒 | Geçmiş sonuçlar (sayfalı, `test_id` ile filtrelenir) |
| GET | `/results/stats` 🔒 | Başarı istatistikleri ve konu kırılımı |
| POST | `/ai/ask` 🔒 | AI koça soru sor (metin veya fotoğraf) |
| GET | `/ai/health` | Ollama durumu ve yüklü modeller |

### Örnek akış

```bash
# 1) Kayıt ol
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"surucu@stopkoc.com","password":"Sifre123"}'

# 2) Dönen access_token ile sonuç kaydet
curl -X POST http://localhost:8000/api/v1/results \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"test_id":1,"score":90}'

# 3) İstatistikleri oku
curl http://localhost:8000/api/v1/results/stats -H "Authorization: Bearer $TOKEN"

# 4) AI koça sor (AI Pro paketi gerekir)
curl -X POST http://localhost:8000/api/v1/ai/ask \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"question":"Alternatör nedir?"}'
```

Araç parçası fotoğrafı göndermek için `images` alanına base64 dizeleri
ekleyin (data URL öneki olmadan). Görsel varsa servis otomatik olarak
`OLLAMA_VISION_MODEL` değerine geçer; Llama 3 metin modeli fotoğrafı
yorumlayamaz.

## Veri modeli

**users** — `id`, `email` (tekil), `password_hash`, `created_at`,
`subscription_status` (`free` | `lifetime_tests` | `ai_pro`)

**test_results** — `id`, `user_id` (FK → `users.id`, ON DELETE CASCADE),
`test_id`, `score` (0-100 kısıtlı), `completed_at`

`subscription_status` değerleri mobil uygulamadaki paketlerle birebir
eşleşir: `lifetime_tests` 99 TL paketi, `ai_pro` 299 TL paketi.

## Güvenlik notları

- **Şifreler** bcrypt ile hashlenir. bcrypt girdiyi 72 baytla sınırladığı
  için şifre önce SHA-256'dan geçirilip base64'lenir (Django'nun
  `BCryptSHA256PasswordHasher` yaklaşımı). Böylece uzun şifreler sessizce
  kırpılmaz. Bkz. `app/core/security.py`.
- `passlib` **kullanılmıyor**: 1.7.4 sürümü `bcrypt` 5.x ile arka uç
  tespiti sırasında `ValueError` fırlatarak kırılıyor.
- **Giriş hataları** hesabın var olup olmadığını sızdırmaz: kullanıcı
  bulunamadığında da bir bcrypt doğrulaması yapılarak yanıt süresi eşitlenir.
- **JWT** HS256 ile imzalanır, `sub` alanında kullanıcı kimliği taşır ve
  varsayılan ömrü 7 gündür. Doğrulama tek yerde: `app/api/deps.py`.
- **Yetki sınırı**: test sonucu yazılırken `user_id` istekten değil
  anahtardan okunur; kullanıcı başkasının adına kayıt oluşturamaz.
- **Üretim koruması**: `ENVIRONMENT=production` iken varsayılan JWT
  anahtarı veya `CORS_ORIGINS=*` ile açılış engellenir (`app/core/config.py`).
- AI uçları varsayılan olarak yalnızca `ai_pro` paketine açıktır; geliştirme
  sırasında `AI_REQUIRES_SUBSCRIPTION=false` ile kapatılabilir.

## Testler

```bash
pytest
```

Testler PostgreSQL yerine bellek içi SQLite, Ollama yerine
`httpx.MockTransport` kullanır; çalıştırmak için harici bir servis
gerekmez. Ollama entegrasyonunda gönderilen isteğin biçimi (sistem
yönergesi, `stream: false`, görsel varken model değişimi) ve hata
eşlemeleri de doğrulanır.

## Proje yapısı

```
app/
  main.py              FastAPI uygulaması, lifespan, hata işleyici
  core/
    config.py          ortam değişkenleri (pydantic-settings)
    database.py        async motor ve oturum bağımlılığı
    security.py        bcrypt hashleme + JWT üretim/doğrulama
    exceptions.py      iş kuralı hataları -> HTTP eşlemesi
  models/              SQLAlchemy tabloları (User, TestResult)
  schemas/             Pydantic istek/yanıt şemaları
  api/
    deps.py            JWT doğrulama ve paket kontrolü bağımlılıkları
    routes/            auth, results, ai uçları
  services/
    auth_service.py    kayıt/giriş iş kuralları
    result_service.py  sonuç kaydı ve SQL tabanlı istatistikler
    ai_service.py      Ollama (Llama 3) istemcisi
alembic/               şema göçleri
tests/                 pytest
```

## Yapılacaklar

- `POST /auth/refresh` ile yenileme anahtarı (şu an tek, uzun ömürlü anahtar var).
- `PATCH /auth/me/subscription` şimdilik istemcinin bildirimine güveniyor;
  canlıya çıkmadan önce RevenueCat webhook'u veya mağaza makbuzu doğrulaması
  eklenmeli.
- AI yanıtlarının akış (streaming) olarak dönmesi — sohbet arayüzünde
  kelime kelime yazma etkisi için.
- İstek hızı sınırlama (rate limit), özellikle `/auth/login` ve `/ai/ask`.
