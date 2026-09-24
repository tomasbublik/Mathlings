-- Mathlings SQLite schema v1
-- Všechna časová pole jsou unix milliseconds (int).
-- Po otevření DB: PRAGMA foreign_keys = ON;

-- meta: verzování schématu a migrace
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);

-- profiles: podpora více dětí na jednom tabletu
CREATE TABLE IF NOT EXISTS profiles (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,
    avatar_key TEXT,
    created_at INTEGER NOT NULL    -- unix ms
);

-- skills: dovednosti sledované Elo ratingem
-- klic je stabilní string: "add_0_20", "sub_0_100", "mul_x7", "div_0_100", ...
CREATE TABLE IF NOT EXISTS skills (
    profile_id  INTEGER NOT NULL,
    skill_key   TEXT    NOT NULL,
    rating      REAL    NOT NULL DEFAULT 1000.0,
    attempts    INTEGER NOT NULL DEFAULT 0,
    correct     INTEGER NOT NULL DEFAULT 0,
    last_seen_at INTEGER,
    PRIMARY KEY (profile_id, skill_key),
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

-- sessions: jedno kolo hry
CREATE TABLE IF NOT EXISTS sessions (
    id           INTEGER PRIMARY KEY,
    profile_id   INTEGER NOT NULL,
    started_at   INTEGER NOT NULL,
    ended_at     INTEGER,
    duration_ms  INTEGER,
    score        INTEGER NOT NULL DEFAULT 0,
    best_streak  INTEGER NOT NULL DEFAULT 0,
    accuracy     REAL,                  -- 0.0-1.0
    config_json  TEXT    NOT NULL,      -- snapshot konfigurace
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

-- attempts: každý zobrazený příklad
CREATE TABLE IF NOT EXISTS attempts (
    id             INTEGER PRIMARY KEY,
    session_id     INTEGER NOT NULL,
    skill_key      TEXT    NOT NULL,
    expression     TEXT    NOT NULL,       -- "7 + 5"
    correct_answer INTEGER NOT NULL,
    choices_json   TEXT    NOT NULL,       -- "[12, 13, 10]"
    chosen_index   INTEGER,                -- NULL pokud minul
    correct        INTEGER NOT NULL,       -- 0/1
    reaction_ms    INTEGER,                -- NULL pokud minul
    shown_at       INTEGER NOT NULL,
    resolved_at    INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- unlocks: odemčené skiny, pozadí, odznaky
CREATE TABLE IF NOT EXISTS unlocks (
    profile_id  INTEGER NOT NULL,
    kind        TEXT    NOT NULL,          -- 'background' | 'skin' | 'badge'
    key         TEXT    NOT NULL,
    unlocked_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, kind, key),
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_attempts_session ON attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_attempts_skill   ON attempts(skill_key);
CREATE INDEX IF NOT EXISTS idx_sessions_profile ON sessions(profile_id, started_at);

-- Seed schema version
INSERT OR IGNORE INTO meta (key, value) VALUES ('schema_version', '1');
