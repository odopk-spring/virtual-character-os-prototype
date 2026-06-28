# 18 — 数据模型草案

## 18.1 完整 ER 概览

```
characters ──1:N──→ messages
    │
    1:N
    ↓
memory_items ────→ memory_contradiction_groups
    │
    ↓ (worldBookEntryIds)
world_book_entries

characters ──1:1──→ character_schedules
characters ──1:1──→ character_current_states
characters ──1:1──→ relationship_states (per user)
characters ──1:N──→ proactive_triggers

user_settings (per device)
api_configurations
notification_preferences
```

## 18.2 核心表 DDL（GRDB/SQLite）

### characters

```sql
CREATE TABLE character (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    nickname TEXT,
    archetype TEXT NOT NULL DEFAULT 'friend',
    core_traits_json TEXT NOT NULL,        -- JSON: [PersonalityTrait]
    speaking_style_json TEXT NOT NULL,      -- JSON: SpeakingStyle
    background TEXT,
    worldview TEXT,
    interests_json TEXT,                    -- JSON: [String]
    dislikes_json TEXT,
    quirks_json TEXT,
    boundaries_json TEXT,
    emotional_range_json TEXT,
    avatar_path TEXT,
    schedule_template_json TEXT,            -- JSON: DailySchedule template
    response_speed_factor REAL DEFAULT 1.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_template INTEGER DEFAULT 0
);
```

### messages

```sql
CREATE TABLE message (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL REFERENCES character(id),
    role TEXT NOT NULL CHECK(role IN ('user','character','system')),
    content TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'normal'
        CHECK(message_type IN ('normal','proactive','system_notification','memory_edit')),
    model_used TEXT,
    token_count INTEGER,
    response_latency REAL,
    proactive_trigger TEXT,
    is_deleted INTEGER DEFAULT 0
);
CREATE INDEX idx_message_character_time ON message(character_id, timestamp);
```

### memory_items

```sql
CREATE TABLE memory_item (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN (
        'episodic','semantic','emotional','relationship',
        'reflection','topicDocument','worldLinked','correction'
    )),
    content TEXT NOT NULL,
    summary TEXT,
    source_message_ids_json TEXT NOT NULL,
    extraction_method TEXT NOT NULL DEFAULT 'autoExtract',
    extraction_model TEXT,
    confidence REAL NOT NULL DEFAULT 0.5,
    importance REAL NOT NULL DEFAULT 0.3,
    emotional_valence REAL,
    emotional_intensity REAL,
    relationship_impact REAL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_accessed_at TEXT NOT NULL,
    event_date TEXT,
    decay_score REAL NOT NULL DEFAULT 1.0,
    decay_rate REAL NOT NULL DEFAULT 0.01,
    contradiction_group_id TEXT,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK(status IN ('active','superseded','deleted','userCorrected','dormant')),
    tags_json TEXT DEFAULT '[]',
    keywords_json TEXT DEFAULT '[]',
    embedding_ref TEXT,
    related_memory_ids_json TEXT DEFAULT '[]',
    world_book_entry_ids_json TEXT DEFAULT '[]',
    topic_document_id TEXT,
    is_user_editable INTEGER NOT NULL DEFAULT 1,
    is_user_visible INTEGER NOT NULL DEFAULT 1,
    user_edited_content TEXT
);
CREATE INDEX idx_memory_character_type ON memory_item(character_id, type);
CREATE INDEX idx_memory_decay ON memory_item(decay_score, last_accessed_at);
CREATE INDEX idx_memory_status ON memory_item(status);
```

### world_book_entries

```sql
CREATE TABLE world_book_entry (
    id TEXT PRIMARY KEY,
    scope TEXT NOT NULL DEFAULT 'character'
        CHECK(scope IN ('global','character','session')),
    character_id TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    keywords_json TEXT DEFAULT '[]',
    aliases_json TEXT DEFAULT '[]',
    activation_rules TEXT,
    priority INTEGER NOT NULL DEFAULT 50,
    cooldown_seconds INTEGER DEFAULT 300,
    entry_type TEXT NOT NULL DEFAULT 'userCustom',
    canon_level TEXT NOT NULL DEFAULT 'headcanon'
        CHECK(canon_level IN ('canon','semiCanon','headcanon','alternative')),
    source TEXT,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    embedding_ref TEXT,
    parent_entry_id TEXT,
    related_entry_ids_json TEXT DEFAULT '[]',
    memory_link_ids_json TEXT DEFAULT '[]',
    is_spoiler INTEGER DEFAULT 0,
    requires_confirmation INTEGER DEFAULT 0
);
CREATE INDEX idx_worldbook_scope ON world_book_entry(scope, character_id);
CREATE INDEX idx_worldbook_type ON world_book_entry(entry_type);
```

### relationship_states

```sql
CREATE TABLE relationship_state (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'acquaintance'
        CHECK(status IN (
            'stranger','acquaintance','casualFriend','closeFriend',
            'collaborator','mentorStudent','companion','ambiguous',
            'intimateAllowedByUser','distant','conflict','repair'
        )),
    familiarity REAL NOT NULL DEFAULT 0.1,
    trust REAL NOT NULL DEFAULT 0.1,
    warmth REAL NOT NULL DEFAULT 0.1,
    conflict REAL NOT NULL DEFAULT 0.0,
    dependency_risk REAL NOT NULL DEFAULT 0.0,
    boundary_pressure REAL NOT NULL DEFAULT 0.0,
    shared_history_depth REAL NOT NULL DEFAULT 0.0,
    reciprocity REAL NOT NULL DEFAULT 0.5,
    user_initiation_rate REAL NOT NULL DEFAULT 0.5,
    character_initiation_rate REAL NOT NULL DEFAULT 0.0,
    total_interactions INTEGER DEFAULT 0,
    total_days_interacted INTEGER DEFAULT 0,
    last_interaction_at TEXT,
    first_interaction_at TEXT,
    user_authorized_intimacy INTEGER DEFAULT 0,
    relationship_notes TEXT,
    updated_at TEXT NOT NULL
);
```

### character_schedules

```sql
CREATE TABLE character_schedule (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL UNIQUE,
    schedule_json TEXT NOT NULL,    -- JSON: DailySchedule
    schedule_type TEXT DEFAULT 'fixed',  -- 'fixed' or 'dynamic'
    generated_at TEXT NOT NULL,
    valid_until TEXT
);
```

### character_current_states

```sql
CREATE TABLE character_current_state (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL UNIQUE,
    timestamp TEXT NOT NULL,
    activity TEXT NOT NULL,
    location TEXT,
    energy_level REAL NOT NULL DEFAULT 0.7,
    mood_valence REAL NOT NULL DEFAULT 0.0,
    mood_arousal REAL NOT NULL DEFAULT 0.5,
    dominant_emotion TEXT DEFAULT 'neutral',
    mood_description TEXT,
    availability TEXT NOT NULL DEFAULT 'normal'
        CHECK(availability IN ('unavailable','delayed','slow','normal','quick')),
    current_plan_description TEXT,
    last_user_interaction TEXT,
    unread_message_count INTEGER DEFAULT 0,
    is_sleeping INTEGER DEFAULT 0,
    busy_until TEXT
);
```

### user_settings

```sql
CREATE TABLE user_setting (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
-- 存储键值对，如：
-- 'proactive_enabled', 'true'
-- 'proactive_frequency', 'medium'
-- 'quiet_hours_start', '22:00'
-- 'quiet_hours_end', '08:00'
-- 'notification_style', 'preview' 或 'anonymous'
-- 'theme', 'default'
```

## 18.3 数据导出格式

```json
{
  "export_version": "1.0",
  "exported_at": "2024-06-15T10:00:00Z",
  "characters": [...],
  "messages": [...],
  "memory_items": [...],
  "world_book_entries": [...],
  "relationship_states": [...]
}
```

用户也可以选择只导出特定角色的数据，或只导出记忆而不导出原始消息。
