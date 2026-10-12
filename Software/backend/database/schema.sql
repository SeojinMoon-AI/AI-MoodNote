-- MoodNote 스키마 v1.2 (SQLite)
-- 회의 결과에 따라 수정될 수 있다. 수정은 이 파일에 반영하고 변경 내용을 아래에 기록한다.
--
-- 변경 기록
-- v1.1 2026-10-04 최초 작성 (테이블 10개)
-- v1.2 2026-10-04 (제안, 회의 확정 필요)
--   - daily_condition: 텍스트 3개(음식, 배변, 운동)를 숫자 칸으로 교체, caffeine_cups 추가 (팀원 의견 반영)
--   - menstrual_cycles 테이블 추가(선택 기능), consents에 cycle_tracking 추가 (테이블 11개)
--
-- 주의
-- 1) SQLite는 연결마다 아래 PRAGMA를 켜야 외래키(CASCADE 삭제)가 작동한다. 앱 코드에서도 연결할 때마다 실행할 것.
-- 2) id는 UUID 문자열을 앱에서 만들어 넣는다(mood_words만 정수 id).
-- 3) 일기 본문, 트라우마 필드 등 민감 필드는 앱 레이어에서 암호화해 저장한다(DB에서는 문자열로 보임).
-- 4) 음성 원본은 DB에 저장하지 않는다. 전사 직후 삭제한다.

PRAGMA foreign_keys = ON;

-- 사용자 (최소 수집: 닉네임, 로그인 ID, 비밀번호 해시만)
CREATE TABLE users (
  id            TEXT PRIMARY KEY,
  nickname      TEXT NOT NULL,
  login_id      TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 선택 입력. 기본 꺼짐으로 운영한다.
CREATE TABLE user_profile (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  characteristics   TEXT,
  dreams_goals      TEXT,
  occupation        TEXT,
  childhood_trauma  TEXT,   -- 민감: 선택 입력, 암호화 대상
  thinking_patterns TEXT,
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE relationships (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  person_name       TEXT NOT NULL,
  relationship_type TEXT,
  notes             TEXT
);

-- 무드미터 100단어 고정 좌표표 (사용자 데이터가 아니라 참조 데이터)
-- id = (grid_row - 1) * 10 + grid_col, energy = 11 - grid_row, pleasantness = grid_col
-- 한국어 단어는 중복될 수 있으므로 (grid_row, grid_col)이 기준 키다.
CREATE TABLE mood_words (
  id           INTEGER PRIMARY KEY,
  word_ko      TEXT NOT NULL,
  word_en      TEXT,
  grid_row     INTEGER NOT NULL CHECK (grid_row BETWEEN 1 AND 10),
  grid_col     INTEGER NOT NULL CHECK (grid_col BETWEEN 1 AND 10),
  energy       INTEGER NOT NULL,
  pleasantness INTEGER NOT NULL,
  zone         TEXT NOT NULL CHECK (zone IN ('red','yellow','blue','green')),
  UNIQUE (grid_row, grid_col),
  CHECK (id = (grid_row - 1) * 10 + grid_col),
  CHECK (energy = 11 - grid_row),
  CHECK (pleasantness = grid_col)
);

CREATE TABLE diary_entries (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mood_word_id      INTEGER REFERENCES mood_words(id),  -- 음성 일기는 나중에 선택하므로 NULL 허용
  entry_date        TEXT NOT NULL,                      -- YYYY-MM-DD
  content           TEXT NOT NULL,                      -- 민감: 암호화 대상
  source            TEXT NOT NULL DEFAULT 'text' CHECK (source IN ('text','voice')),
  trigger_event     TEXT,                               -- 선택 입력 (회의 결정 반영)
  automatic_thought TEXT,                               -- 선택 입력 (화면에서는 "그때 든 생각")
  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_diary_user_date ON diary_entries(user_id, entry_date);

CREATE TABLE ai_feedback (
  id               TEXT PRIMARY KEY,
  entry_id         TEXT NOT NULL REFERENCES diary_entries(id) ON DELETE CASCADE,
  feedback_type    TEXT NOT NULL CHECK (feedback_type IN ('empathy','reframe','body_care')),
  feedback_text    TEXT NOT NULL,
  perceived_desire TEXT,  -- AI의 추정(가설). 사용자가 확인한 것만 self_model로 올린다.
  user_reaction    TEXT CHECK (user_reaction IN ('helpful','not_helpful','neutral')),
  user_note        TEXT,
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_feedback_entry ON ai_feedback(entry_id);

-- 하루 상태: 모든 칸은 비워둘 수 있다(선택 입력). 텍스트 대신 숫자로 저장해 그래프와 추세 계산을 쉽게 한다.
-- 1~5 척도의 뜻(팀 확정 필요): sleep_score 1=매우 나쁨 ~ 5=매우 좋음 / appetite_score 1=거의 없음 ~ 5=아주 좋음 /
--                              bowel_score 1=매우 불편 ~ 5=매우 편안
CREATE TABLE daily_condition (
  id               TEXT PRIMARY KEY,
  user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  log_date         TEXT NOT NULL,                                          -- YYYY-MM-DD
  sleep_hours      REAL    CHECK (sleep_hours BETWEEN 0 AND 24),           -- 객관 값(웨어러블 연동 가능)
  sleep_score      INTEGER CHECK (sleep_score BETWEEN 1 AND 5),            -- 주관 값
  meal_count       INTEGER CHECK (meal_count BETWEEN 0 AND 10),            -- 끼니 수
  appetite_score   INTEGER CHECK (appetite_score BETWEEN 1 AND 5),         -- 식욕
  bowel_score      INTEGER CHECK (bowel_score BETWEEN 1 AND 5),            -- 배변 상태
  exercise_minutes INTEGER CHECK (exercise_minutes BETWEEN 0 AND 1440),   -- 운동 시간(분)
  caffeine_cups    INTEGER CHECK (caffeine_cups BETWEEN 0 AND 20),         -- 카페인 음료(잔), 선택
  source           TEXT NOT NULL DEFAULT 'self' CHECK (source IN ('self','wearable')),
  UNIQUE (user_id, log_date, source)
);
CREATE INDEX idx_condition_user_date ON daily_condition(user_id, log_date);

-- 월경 주기 기록(선택 기능, 별도 동의 cycle_tracking). 시작일과 종료일만 저장한다.
-- 주기 길이와 "주기 몇 일째인지"는 저장하지 않고 조회할 때 계산한다. 기본적으로 AI 프롬프트에 넣지 않는다.
CREATE TABLE menstrual_cycles (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_date TEXT NOT NULL,                                -- YYYY-MM-DD
  end_date   TEXT,                                         -- 아직 진행 중이면 NULL
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (user_id, start_date),
  CHECK (end_date IS NULL OR end_date >= start_date)
);
CREATE INDEX idx_cycles_user ON menstrual_cycles(user_id, start_date);

-- 11/18에는 테이블만 만들고 자동 갱신은 하지 않는다.
CREATE TABLE self_model (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  confirmed_patterns TEXT,
  probable_patterns  TEXT,
  hypotheses         TEXT,
  unknown_areas      TEXT,
  updated_at         TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 안전장치 기록. 일기 본문은 복사해 저장하지 않는다. 접근은 시스템만.
CREATE TABLE safety_events (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entry_id     TEXT REFERENCES diary_entries(id) ON DELETE CASCADE,  -- 패턴(L3)은 NULL
  level        INTEGER NOT NULL CHECK (level IN (1,2,3)),
  trigger_type TEXT NOT NULL CHECK (trigger_type IN ('keyword','llm','pattern')),
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_safety_user ON safety_events(user_id, created_at);

-- 동의 기록. 동의 행이 없으면 "동의 안 함"이다(기본 off).
CREATE TABLE consents (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL CHECK (consent_type IN
                 ('diary_storage','voice_processing','ai_counseling','expert_export','ai_training','cycle_tracking')),
  version      TEXT NOT NULL,                       -- 동의 문구 버전
  granted_at   TEXT NOT NULL DEFAULT (datetime('now')),
  revoked_at   TEXT                                 -- 철회하면 시각을 채운다
);
CREATE INDEX idx_consents_user ON consents(user_id, consent_type);

-- AI 학습 동의 여부는 consents에서 계산한다(같은 값을 두 곳에 저장하지 않기 위해 별도 컬럼을 두지 않는다).
CREATE VIEW v_ai_training_opt_in AS
SELECT u.id AS user_id,
       EXISTS (
         SELECT 1 FROM consents c
         WHERE c.user_id = u.id AND c.consent_type = 'ai_training' AND c.revoked_at IS NULL
       ) AS opted_in
FROM users u;
