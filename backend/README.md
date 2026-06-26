# AgriPulse — Core Backend

The **Core Engine** from the architecture diagram: FastAPI + PostgreSQL with JWT
auth, role-based access control (RBAC), and the business logic for all three roles
(**farmer · seller · analyst**).

ML lives in the separate `../ml_train/serving` (plant-disease CNN, fertilizer
XGBoost, FLAN-T5 chatbot). This backend *calls* it over HTTP — see
`app/services/ai_client.py`.

```
Frontend app ──HTTP──►  backend (this)  ──HTTP──►  ml_train/serving (ML)
                              │
                              ▼
                        PostgreSQL  ◄── schema · migrations · seed in ../database
```

## Folder map
```
backend/
├── app/
│   ├── main.py            # FastAPI app, CORS, registers all routers
│   ├── config.py          # settings from .env
│   ├── database.py        # SQLAlchemy engine + get_db()
│   ├── security.py        # bcrypt hashing + JWT create/decode
│   ├── deps.py            # get_current_user + require_role()  ← AUTH/RBAC middleware
│   ├── models.py          # ALL database tables (the schema)
│   ├── schemas.py         # Pydantic request/response shapes
│   ├── seed.py            # loads ../database/seed/data/*.csv into the DB
│   ├── services/ai_client.py   # calls ml_train/serving ML endpoints
│   └── routes/
│       ├── auth.py        # register / login / me
│       ├── farmer.py      # profile, crop history, disease, fertilizer
│       ├── seller.py      # products, incoming orders, analytics
│       ├── analyst.py     # regional analytics, community monitoring
│       ├── broadcast.py   # disaster broadcasts (analyst → regions)
│       ├── appointments.py# consultation booking + analyst management
│       ├── community.py   # posts / comments / likes (all roles)
│       ├── marketplace.py # browse products + place orders (farmer)
│       ├── weather.py     # weather + disaster alerts (all roles)
│       ├── assistant.py   # AI chatbot proxy (all roles)
│       └── common.py      # /regions lookup
└── requirements.txt
```

> Seed CSVs and the SQL schema/migrations now live in [`../database`](../database)
> (one place for all DB artifacts). `python -m app.seed` reads them from there.

---

## Setup — step by step

### 1. Install PostgreSQL & create the database
**macOS (Homebrew):**
```bash
brew install postgresql@16
brew services start postgresql@16
```
Create the DB and user (matches the defaults in `.env.example`):
```bash
psql postgres -c "CREATE USER agripulse WITH PASSWORD 'agripulse';"
psql postgres -c "CREATE DATABASE agripulse OWNER agripulse;"
```
> Prefer Docker? `docker run --name agri-pg -e POSTGRES_USER=agripulse -e POSTGRES_PASSWORD=agripulse -e POSTGRES_DB=agripulse -p 5432:5432 -d postgres:16`

### 2. Python environment + dependencies
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Configure environment
```bash
cp .env.example .env
python -c "import secrets; print(secrets.token_hex(32))"   # paste into SECRET_KEY
```
Edit `.env` if your DB user/password/host differ.

### 4. Create tables + load seed data
```bash
python -m app.seed
```
This creates every table and loads the sample farmers, sellers, the analyst,
products, orders, posts, and disaster broadcasts. Re-run with `--reset` to wipe and reload.

### 5. Run the API
```bash
uvicorn app.main:app --reload --port 8000
```
Open **http://localhost:8000/docs** — interactive Swagger UI.

### 6. Try it (in the docs UI or curl)
```bash
# Login (form-encoded; username = email)
curl -X POST http://localhost:8000/auth/login \
  -d "username=farmer1@agripulse.com&password=Pass1234"
# → copy the access_token, then in /docs click "Authorize" and paste it.
```

### 7. (Optional) Run the AI service too
In a second terminal so disease/fertilizer endpoints work end-to-end:
```bash
cd ../ai_service
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```
(Match `AI_SERVICE_URL=http://localhost:8001` in `backend/.env`.)

---

## Seeded test accounts
| Role    | Email                  | Password   |
|---------|------------------------|------------|
| Farmer  | farmer1@agripulse.com  | `Pass1234` |
| Seller  | seller1@agripulse.com  | `Pass1234` |
| Analyst | udita@gmail.com        | `2102006`  |

## Key endpoints by role
| Role | Endpoints |
|------|-----------|
| **All** | `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `GET /regions`, `/community/*`, `/weather/alerts`, `/assistant/chat`, `GET /broadcasts` |
| **Farmer** | `/farmer/profile`, `/farmer/crop-history`, `/farmer/disease/detect`, `/farmer/fertilizer/recommend`, `/farmer/nearby-sellers`, `/marketplace/*`, `/appointments` |
| **Seller** | `/seller/products`, `/seller/orders`, `/seller/analytics` |
| **Analyst** | `/analyst/regional-analytics`, `/analyst/community-monitor`, `POST /broadcasts`, `/appointments/all`, `/appointments/{id}/status` |

## How auth + RBAC works (for the report)
1. `POST /auth/login` validates the password (bcrypt) and returns a **JWT** containing
   the user id + role.
2. Flutter stores the token and sends it as `Authorization: Bearer <token>` on every call.
3. `get_current_user` (in `deps.py`) decodes the token and loads the user — **Authentication**.
4. `require_role(Role.analyst)` rejects anyone without that role with `403` — **Authorization (RBAC)**.

## Production notes
- Swap `Base.metadata.create_all` for **Alembic** migrations once the schema is stable.
- Restrict `allow_origins` in `main.py` to your real Flutter domain.
- Store uploaded images in object storage (S3 / Firebase Storage) and save the URL.
