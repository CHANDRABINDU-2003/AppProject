-- ============================================================================
-- AgriPulse — PostgreSQL schema (DDL)
-- ----------------------------------------------------------------------------
-- This is the canonical, human-readable definition of the AgriPulse database.
-- It mirrors the SQLAlchemy ORM models in backend/app/models.py one-to-one
-- (one class = one table) and is what the report's ER diagram is drawn from.
--
-- Apply directly (fresh DB):
--     psql -U agripulse -d agripulse -f database/schema/schema.sql
-- Or let the backend create tables from the ORM (dev), or use Alembic
-- migrations under database/migrations/ for versioned changes.
-- ============================================================================

BEGIN;

-- ─────────────────────────── Enum types ───────────────────────────
DROP TYPE IF EXISTS role CASCADE;
DROP TYPE IF EXISTS orderstatus CASCADE;
DROP TYPE IF EXISTS appointmentstatus CASCADE;
DROP TYPE IF EXISTS severity CASCADE;
DROP TYPE IF EXISTS broadcastcategory CASCADE;

-- farmer + seller are the two registerable user roles; analyst is a single,
-- pre-provisioned oversight account (not registerable).
CREATE TYPE role        AS ENUM ('farmer', 'seller', 'analyst');
CREATE TYPE orderstatus AS ENUM ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled');
CREATE TYPE appointmentstatus AS ENUM ('pending', 'confirmed', 'completed', 'cancelled');
CREATE TYPE severity    AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE broadcastcategory AS ENUM
    ('flood', 'cyclone', 'heavy_rain', 'pest_outbreak', 'disease_outbreak');

-- ─────────────────────────── Reference ───────────────────────────
-- 8 regions (e.g. the 8 divisions); used to match nearby farmers and sellers.
CREATE TABLE regions (
    id          SERIAL PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL UNIQUE
);

-- ─────────────────────────── Knowledge masters (RAG context) ───────────────────────────
-- Curated reference tables searched BEFORE the FLAN-T5 chatbot runs so its
-- answers are grounded in real facts (a small Retrieval-Augmented Generation
-- step). See backend/app/services/knowledge.py.
CREATE TABLE crop_master (
    id                SERIAL PRIMARY KEY,
    name              VARCHAR(100) UNIQUE NOT NULL,
    description       TEXT,
    season            VARCHAR(100),
    water_requirement VARCHAR(100)
);
CREATE INDEX ix_crop_master_name ON crop_master (name);

CREATE TABLE disease_master (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(200) UNIQUE NOT NULL,
    symptoms TEXT,
    solution TEXT
);
CREATE INDEX ix_disease_master_name ON disease_master (name);

CREATE TABLE fertilizer_master (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(100) UNIQUE NOT NULL,
    used_for TEXT
);
CREATE INDEX ix_fertilizer_master_name ON fertilizer_master (name);

-- ─────────────────────────── Users (all roles) ───────────────────────────
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    password_hash TEXT         NOT NULL,
    role          role         NOT NULL,
    region_id     INTEGER      REFERENCES regions(id),
    is_active     BOOLEAN      DEFAULT TRUE,
    created_at    TIMESTAMP    DEFAULT (now() AT TIME ZONE 'utc')
);
CREATE INDEX ix_users_email ON users(email);
CREATE INDEX ix_users_role  ON users(role);

-- ─────────────────────────── Farmer domain ───────────────────────────
CREATE TABLE farmers (
    id        SERIAL PRIMARY KEY,
    user_id   INTEGER NOT NULL UNIQUE REFERENCES users(id),
    farm_size DOUBLE PRECISION,           -- acres / hectares
    soil_type VARCHAR(50),
    main_crop VARCHAR(50)
);

CREATE TABLE crop_history (
    id              SERIAL PRIMARY KEY,
    farmer_id       INTEGER NOT NULL REFERENCES farmers(id),
    crop_type       VARCHAR(50),
    season          VARCHAR(20),           -- Kharif | Rabi | Zaid
    yield_amount    DOUBLE PRECISION,
    fertilizer_used VARCHAR(100),
    quantity        DOUBLE PRECISION,      -- amount grown/sold
    price           DOUBLE PRECISION,      -- price per unit the farmer recorded
    crop_date       VARCHAR(20),           -- ISO yyyy-mm-dd the farmer logged
    created_at      TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

-- ─────────────────────────── ML result records ───────────────────────────
CREATE TABLE fertilizer_predictions (
    id                   SERIAL PRIMARY KEY,
    farmer_id            INTEGER NOT NULL REFERENCES farmers(id),
    input_data           JSONB,            -- raw features sent to the model
    predicted_fertilizer VARCHAR(100),
    confidence           DOUBLE PRECISION,
    created_at           TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE TABLE disease_results (
    id           SERIAL PRIMARY KEY,
    farmer_id    INTEGER NOT NULL REFERENCES farmers(id),
    image_url    TEXT,
    disease_name VARCHAR(100),
    confidence   DOUBLE PRECISION,
    created_at   TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

-- ─────────────────────────── Community ───────────────────────────
CREATE TABLE posts (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(id),
    text       TEXT,
    image_url  TEXT,
    likes      INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE TABLE comments (
    id         SERIAL PRIMARY KEY,
    post_id    INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id    INTEGER NOT NULL REFERENCES users(id),
    comment    TEXT,
    created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

-- ─────────────────────────── Seller / commerce ───────────────────────────
CREATE TABLE products (
    id        SERIAL PRIMARY KEY,
    seller_id INTEGER NOT NULL REFERENCES users(id),
    name      VARCHAR(100) NOT NULL,
    type      VARCHAR(50),                 -- fertilizer | pesticide | seed | tool
    price     DOUBLE PRECISION,
    stock     INTEGER DEFAULT 0,
    region_id INTEGER REFERENCES regions(id)
);

CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    farmer_id  INTEGER NOT NULL REFERENCES farmers(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity   INTEGER DEFAULT 1,
    status     orderstatus DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

-- ─────────────────────────── Consultations / appointments ───────────────────────────
-- A farmer books a consultation with the single analyst oversight account.
CREATE TABLE appointments (
    id             SERIAL PRIMARY KEY,
    farmer_id      INTEGER NOT NULL REFERENCES farmers(id),
    expert_id      INTEGER NOT NULL,            -- the analyst's user id (snapshot)
    expert_name    VARCHAR(100) NOT NULL,       -- the analyst's name  (snapshot)
    scheduled_date VARCHAR(20) NOT NULL,        -- ISO yyyy-mm-dd
    scheduled_time VARCHAR(10),                 -- HH:MM (optional)
    topic          TEXT,
    status         appointmentstatus DEFAULT 'pending',
    created_at     TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

-- ─────────────────────────── Disaster broadcasts (analyst → region) ───────────────────────────
-- Early-warning alerts the analyst pushes to a region (or all regions, when
-- region_id is NULL). Read by farmers and sellers to plan around the hazard.
CREATE TABLE broadcasts (
    id                 SERIAL PRIMARY KEY,
    title              VARCHAR(150) NOT NULL,
    category           broadcastcategory NOT NULL,
    description        TEXT,
    region_id          INTEGER REFERENCES regions(id),   -- NULL = all regions
    severity           severity NOT NULL DEFAULT 'medium',
    event_date         VARCHAR(20),                       -- ISO yyyy-mm-dd
    created_by_analyst INTEGER NOT NULL,                  -- the analyst's user id
    created_at         TIMESTAMP DEFAULT (now() AT TIME ZONE 'utc')
);

COMMIT;
