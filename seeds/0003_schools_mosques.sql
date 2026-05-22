-- Migration: create schools and mosques tables (run before seed_v1_migration.sql)
-- These are institutional tables, separate from the listings/provider model.

CREATE TABLE IF NOT EXISTS schools (
    id          UUID        PRIMARY KEY,
    kanton      CHAR(2)     NOT NULL,
    region      TEXT        NOT NULL,
    school_name TEXT,
    day         TEXT,
    time        TEXT,
    address     TEXT,
    flag_url    TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schools_kanton ON schools(kanton);

CREATE TABLE IF NOT EXISTS mosques (
    id               UUID  PRIMARY KEY,
    kanton           CHAR(2) NOT NULL,
    association_name TEXT    NOT NULL,
    address          TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mosques_kanton ON mosques(kanton);
