# AgriPulse 🌾

A role-based smart-farming platform for **farmers, sellers, and an analyst** —
AI crop-disease detection, fertilizer recommendations, a farming chatbot, a
marketplace, disaster broadcasts, and a community feed.

Each role logs into its own **multi-page dashboard** (a responsive navigation-rail
shell, not a flash-card menu) backed by a FastAPI core, a separate ML service,
and PostgreSQL.

## Repository layout

The project is split into four top-level folders, each self-contained:

```
agripulse/
├── frontend/      Flutter client — responsive role dashboards (rail ↔ bottom nav)
├── backend/       FastAPI core — auth, RBAC, business logic               ── port 8000
├── ml_train/      ML training pipelines + serving FastAPI (3 models)      ── port 8001
│   ├── serving/        model-serving API the backend calls
│   ├── plant_disease/  PyTorch CNN          fertilizer/  XGBoost
│   └── chatbot/        FLAN-T5 (LoRA)
└── database/      PostgreSQL schema (DDL) · Alembic migrations · seed data
```

| Folder | Role | Stack | Port | Docs |
|--------|------|-------|------|------|
| `frontend/` | Mobile/web client, role dashboards | Flutter | — | [README](frontend/README.md) |
| `backend/` | Auth, RBAC, users, community, orders, alerts | FastAPI + PostgreSQL | 8000 | [README](backend/README.md) |
| `ml_train/` | Train + serve disease / fertilizer / chatbot models | PyTorch · XGBoost · FLAN-T5 | 8001 | [README](ml_train/README.md) |
| `database/` | Schema, migrations, seed data | PostgreSQL · Alembic | — | [README](database/README.md) |

```
frontend (Flutter)        farmer · seller · analyst
        │  REST + JWT
        ▼
backend (FastAPI)         auth · RBAC · business logic ───────►  PostgreSQL  ◄── database/
        │  HTTP (ML only)
        ▼
ml_train/serving (FastAPI)  serves 3 trained models from ml_train/
```

**Models** (already trained, on disk): plant disease — EfficientNet-B0 (15 classes);
fertilizer — XGBoost; chatbot — fine-tuned FLAN-T5.

## Prerequisites

| Tool | Version |
|------|---------|
| Python | 3.10–3.12 (not 3.13+) |
| PostgreSQL | 14–16 |
| Flutter | 3.x stable |

## How to run

Three processes, each in its own terminal. Start in order: ML service → backend → app.

### 1. Database (once)

```bash
brew services start postgresql@16
psql postgres -c "CREATE USER agripulse WITH PASSWORD 'agripulse';"
psql postgres -c "CREATE DATABASE agripulse OWNER agripulse;"
```

Schema, migrations and seed data live in [`database/`](database/README.md). The
backend seeder (step 3) creates the tables and loads demo data for you; for a
versioned setup use `cd database/migrations && alembic upgrade head`.

### 2. ML service — terminal 1, port 8001

```bash
cd ml_train/serving
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

Check: http://localhost:8001/docs

### 3. Backend — terminal 2, port 8000

```bash
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python -c "import secrets; print(secrets.token_hex(32))"   # → paste into SECRET_KEY
python -m app.seed      # creates tables + loads database/seed/data/*.csv
uvicorn app.main:app --reload --port 8000
```

Check: http://localhost:8000/docs

### 4. Frontend app — terminal 3

Set `apiBaseUrl` in `frontend/lib/config.dart`:

| Target | URL |
|--------|-----|
| Web / desktop / iOS simulator | `http://localhost:8000` (default) |
| Android emulator | `http://10.0.2.2:8000` |
| Real phone | your LAN IP, e.g. `http://192.168.0.10:8000` |

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### 5. Log in

| Role | Email | Password |
|------|-------|----------|
| Farmer | `farmer1@agripulse.com` | `Pass1234` |
| Seller | `seller1@agripulse.com` | `Pass1234` |
| Analyst | `udita@gmail.com` | `2102006` |

## Daily restart

Setup is done; just start the three terminals:

```bash
cd ml_train/serving && source .venv/bin/activate && uvicorn app.main:app --reload --port 8001
cd backend          && source .venv/bin/activate && uvicorn app.main:app --reload --port 8000
cd frontend         && flutter run -d chrome
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| DB connection errors | Start PostgreSQL: `brew services start postgresql@16` |
| `pip install` fails on torch/xgboost | Recreate venv with `python3.12` (not 3.13+) |
| Disease/fertilizer calls fail | ML service not running, or wrong `AI_SERVICE_URL` in `backend/.env` |
| App can't reach backend | Fix `apiBaseUrl` in `frontend/lib/config.dart`; on Android allow cleartext HTTP |

## More docs

- Frontend dashboard architecture → [`frontend/README.md`](frontend/README.md)
- Backend schema, endpoints, RBAC → [`backend/README.md`](backend/README.md)
- ML training + serving → [`ml_train/README.md`](ml_train/README.md)
- Database schema, ER diagram, migrations → [`database/README.md`](database/README.md)
