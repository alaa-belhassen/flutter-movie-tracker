const Database = require('better-sqlite3');
const fs = require('node:fs');
const path = require('node:path');

function createDatabase(filename = process.env.DATABASE_PATH || './data/movietracker.sqlite') {
  if (filename !== ':memory:') {
    fs.mkdirSync(path.dirname(path.resolve(filename)), { recursive: true });
  }
  const database = new Database(filename);
  database.pragma('foreign_keys = ON');
  if (filename !== ':memory:') {
    database.pragma('journal_mode = WAL');
  }

  database.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL COLLATE NOCASE UNIQUE,
      nickname TEXT NOT NULL COLLATE NOCASE UNIQUE,
      password_hash TEXT NOT NULL,
      country TEXT NOT NULL DEFAULT 'US',
      favorite_genres TEXT NOT NULL DEFAULT '[]',
      is_moderator INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id);

    CREATE TABLE IF NOT EXISTS user_movies (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      movie_id TEXT NOT NULL,
      kind TEXT NOT NULL CHECK (kind IN ('watchlist', 'favorite')),
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, movie_id, kind)
    );
    CREATE INDEX IF NOT EXISTS user_movies_lookup_idx ON user_movies(user_id, kind);

    CREATE TABLE IF NOT EXISTS followed_actors (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      actor_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, actor_id)
    );
    CREATE INDEX IF NOT EXISTS followed_actors_user_idx
      ON followed_actors(user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS recommendation_exclusions (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      movie_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, movie_id)
    );

    CREATE TABLE IF NOT EXISTS custom_lists (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      movie_ids TEXT NOT NULL DEFAULT '[]',
      is_shared INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS custom_lists_user_id_idx ON custom_lists(user_id);

    CREATE TABLE IF NOT EXISTS custom_list_members (
      list_id TEXT NOT NULL REFERENCES custom_lists(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      invited_by TEXT NOT NULL REFERENCES users(id),
      created_at TEXT NOT NULL,
      PRIMARY KEY (list_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS custom_list_members_user_idx
      ON custom_list_members(user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS viewing_entries (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      movie_id TEXT NOT NULL,
      watched_at TEXT NOT NULL,
      rating REAL,
      is_rewatch INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS viewing_entries_user_date_idx
      ON viewing_entries(user_id, watched_at DESC);
    CREATE INDEX IF NOT EXISTS viewing_entries_user_movie_idx
      ON viewing_entries(user_id, movie_id);

    CREATE TABLE IF NOT EXISTS reviews (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      movie_id TEXT NOT NULL,
      rating REAL NOT NULL,
      content TEXT NOT NULL,
      contains_spoiler INTEGER NOT NULL DEFAULT 0,
      is_rewatch INTEGER NOT NULL DEFAULT 0,
      helpful_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE (user_id, movie_id)
    );
    CREATE INDEX IF NOT EXISTS reviews_movie_date_idx
      ON reviews(movie_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS review_helpful_votes (
      review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL,
      PRIMARY KEY (review_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS forum_topics (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      movie_id TEXT,
      author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL,
      is_hidden INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS forum_topics_date_idx
      ON forum_topics(is_hidden, created_at DESC);

    CREATE TABLE IF NOT EXISTS forum_messages (
      id TEXT PRIMARY KEY,
      topic_id TEXT NOT NULL REFERENCES forum_topics(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS forum_messages_topic_date_idx
      ON forum_messages(topic_id, is_deleted, created_at);

    CREATE TABLE IF NOT EXISTS forum_message_likes (
      message_id TEXT NOT NULL REFERENCES forum_messages(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL,
      PRIMARY KEY (message_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS forum_reports (
      id TEXT PRIMARY KEY,
      target_type TEXT NOT NULL CHECK (target_type IN ('message', 'topic')),
      target_id TEXT NOT NULL,
      reporter_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      reason TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'dismissed', 'removed', 'restricted')),
      created_at TEXT NOT NULL,
      UNIQUE (target_type, target_id, reporter_id)
    );
    CREATE INDEX IF NOT EXISTS forum_reports_pending_idx
      ON forum_reports(status, created_at);

    CREATE TABLE IF NOT EXISTS forum_restrictions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      moderator_id TEXT NOT NULL REFERENCES users(id),
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL,
      lifted_at TEXT
    );
    CREATE INDEX IF NOT EXISTS forum_restrictions_active_idx
      ON forum_restrictions(user_id, lifted_at);
  `);

  const userColumns = database.prepare('PRAGMA table_info(users)').all();
  if (!userColumns.some((column) => column.name === 'is_moderator')) {
    database.exec(
      'ALTER TABLE users ADD COLUMN is_moderator INTEGER NOT NULL DEFAULT 0',
    );
  }

  return database;
}

module.exports = { createDatabase };
