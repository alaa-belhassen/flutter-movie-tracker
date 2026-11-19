const { randomUUID } = require('node:crypto');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const express = require('express');
const { rateLimit } = require('express-rate-limit');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ADMIN_EMAIL = 'admin@admin.com';
const ADMIN_PASSWORD = 'admin';
const LOCAL_ORIGIN_PATTERNS = new Set([
  'http://localhost:*',
  'http://127.0.0.1:*',
]);
const GENRES = new Set([
  'Action',
  'Sci-Fi',
  'Adventure',
  'Animation',
  'Comedy',
  'Crime',
  'Documentary',
  'Drama',
  'Family',
  'Fantasy',
  'History',
  'Horror',
  'Music',
  'Mystery',
  'Romance',
  'Science Fiction',
  'Thriller',
  'War',
  'Western',
]);

function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    nickname: row.nickname,
    country: row.country,
    favoriteGenres: JSON.parse(row.favorite_genres),
    isModerator: Boolean(row.is_moderator),
    createdAt: row.created_at,
  };
}

function createApp({
  database,
  jwtSecret = process.env.JWT_SECRET,
  corsOrigins = process.env.CORS_ORIGINS ||
    'http://localhost:*,http://127.0.0.1:*',
  adminPassword = process.env.ADMIN_PASSWORD || ADMIN_PASSWORD,
  passwordHashRounds = Number(process.env.PASSWORD_HASH_ROUNDS || 12),
}) {
  if (!database) throw new Error('A database instance is required.');
  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error(
      'JWT_SECRET is missing or too short. Create backend/.env from ' +
      'backend/.env.example and set JWT_SECRET to a random value of at ' +
      'least 32 characters.',
    );
  }

  const adminUser = database.prepare(
    'SELECT id FROM users WHERE email = ?',
  ).get(ADMIN_EMAIL);
  if (!adminUser) {
    let nickname = 'admin';
    if (database.prepare('SELECT 1 FROM users WHERE nickname = ?').get(nickname)) {
      nickname = `admin_${randomUUID().slice(0, 8)}`;
    }
    database.prepare(`
      INSERT INTO users (
        id, email, nickname, password_hash, country, favorite_genres,
        is_moderator, created_at
      ) VALUES (?, ?, ?, ?, 'US', '[]', 1, ?)
    `).run(
      randomUUID(),
      ADMIN_EMAIL,
      nickname,
      bcrypt.hashSync(adminPassword, passwordHashRounds),
      new Date().toISOString(),
    );
  }
  database.prepare(`
    UPDATE users SET is_moderator = CASE WHEN email = ? THEN 1 ELSE 0 END
  `).run(ADMIN_EMAIL);

  const app = express();
  const allowedOrigins = corsOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  function isAllowedOrigin(origin) {
    if (allowedOrigins.includes(origin)) return true;
    if (![...LOCAL_ORIGIN_PATTERNS].some((pattern) =>
      allowedOrigins.includes(pattern))) {
      return false;
    }

    try {
      const parsedOrigin = new URL(origin);
      return parsedOrigin.protocol === 'http:' &&
        ['localhost', '127.0.0.1'].includes(parsedOrigin.hostname);
    } catch {
      return false;
    }
  }

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({
    origin(origin, callback) {
      if (!origin || isAllowedOrigin(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Origin is not allowed by CORS.'));
      }
    },
  }));
  app.use(express.json({ limit: '16kb' }));

  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 20,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
  });

  function issueSession(user, rememberMe) {
    const sessionId = randomUUID();
    const lifetimeSeconds = rememberMe ? 30 * 24 * 60 * 60 : 12 * 60 * 60;
    const expiresAt = Math.floor(Date.now() / 1000) + lifetimeSeconds;
    database.prepare(`
      INSERT INTO sessions (id, user_id, expires_at, created_at)
      VALUES (?, ?, ?, ?)
    `).run(sessionId, user.id, expiresAt, new Date().toISOString());

    const token = jwt.sign(
      { sub: user.id, jti: sessionId },
      jwtSecret,
      { expiresIn: lifetimeSeconds, issuer: 'movietracker-api' },
    );
    return { token, user: publicUser(user) };
  }

  function authenticate(request, response, next) {
    const authorization = request.get('authorization') || '';
    const [scheme, token] = authorization.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return response.status(401).json({ error: 'Authentication required.' });
    }

    try {
      const payload = jwt.verify(token, jwtSecret, { issuer: 'movietracker-api' });
      if (typeof payload !== 'object' || !payload.sub || !payload.jti) {
        return response.status(401).json({ error: 'Invalid session.' });
      }

      const session = database.prepare(`
        SELECT sessions.id AS session_id, sessions.expires_at,
               users.id, users.email, users.nickname,
               users.country, users.favorite_genres, users.is_moderator,
               users.created_at
        FROM sessions
        JOIN users ON users.id = sessions.user_id
        WHERE sessions.id = ? AND sessions.user_id = ? AND sessions.expires_at > ?
      `).get(payload.jti, payload.sub, Math.floor(Date.now() / 1000));

      if (!session) {
        return response.status(401).json({ error: 'Session expired or revoked.' });
      }

      request.auth = { sessionId: session.session_id, user: publicUser(session) };
      return next();
    } catch (error) {
      if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
        return response.status(401).json({ error: 'Invalid or expired session.' });
      }
      return next(error);
    }
  }

  function requireModerator(request, response, next) {
    if (!request.auth.user.isModerator) {
      return response.status(403).json({ error: 'Moderator access required.' });
    }
    return next();
  }

  app.get('/api/health', (request, response) => response.json({ status: 'ok' }));

  app.post('/api/auth/register', authLimiter, async (request, response, next) => {
    try {
      const email = typeof request.body.email === 'string'
        ? request.body.email.trim().toLowerCase()
        : '';
      const password = request.body.password;
      const nickname = typeof request.body.nickname === 'string'
        ? request.body.nickname.trim()
        : '';
      const country = typeof request.body.country === 'string'
        ? request.body.country.trim().toUpperCase()
        : 'US';
      const favoriteGenres = request.body.favoriteGenres ?? [];

      if (!EMAIL_PATTERN.test(email) || email.length > 254) {
        return response.status(400).json({ error: 'Enter a valid email address.' });
      }
      if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
        return response.status(400).json({ error: 'Password must be between 8 and 128 characters.' });
      }
      if (nickname.length < 2 || nickname.length > 32) {
        return response.status(400).json({ error: 'Nickname must be between 2 and 32 characters.' });
      }
      if (!/^[A-Z]{2}$/.test(country)) {
        return response.status(400).json({ error: 'Country must be a two-letter code.' });
      }
      if (!Array.isArray(favoriteGenres) || favoriteGenres.length > GENRES.size ||
          favoriteGenres.some((genre) => typeof genre !== 'string' || !GENRES.has(genre))) {
        return response.status(400).json({ error: 'Favorite genres contain an invalid value.' });
      }

      const user = {
        id: randomUUID(),
        email,
        nickname,
        country,
        favorite_genres: JSON.stringify([...new Set(favoriteGenres)]),
        is_moderator: 0,
        created_at: new Date().toISOString(),
      };
      const passwordHash = await bcrypt.hash(password, passwordHashRounds);

      try {
        database.prepare(`
          INSERT INTO users (
            id, email, nickname, password_hash, country, favorite_genres,
            is_moderator, created_at
          ) VALUES (
            @id, @email, @nickname, @passwordHash, @country, @favorite_genres,
            @is_moderator, @created_at
          )
        `).run({ ...user, passwordHash });
      } catch (error) {
        if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
          return response.status(409).json({ error: 'Email or nickname is already registered.' });
        }
        throw error;
      }

      return response.status(201).json(issueSession(user, true));
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/auth/login', authLimiter, async (request, response, next) => {
    try {
      const email = typeof request.body.email === 'string'
        ? request.body.email.trim().toLowerCase()
        : '';
      const password = request.body.password;
      if (!EMAIL_PATTERN.test(email) || typeof password !== 'string') {
        return response.status(401).json({ error: 'Email or password is incorrect.' });
      }

      const user = database.prepare('SELECT * FROM users WHERE email = ?').get(email);
      const validPassword = user
        ? await bcrypt.compare(password, user.password_hash)
        : false;
      if (!validPassword) {
        return response.status(401).json({ error: 'Email or password is incorrect.' });
      }

      return response.json(issueSession(user, request.body.rememberMe !== false));
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/auth/me', authenticate, (request, response) => {
    response.json({ user: request.auth.user });
  });

  app.post('/api/auth/logout', authenticate, (request, response) => {
    database.prepare('DELETE FROM sessions WHERE id = ?').run(request.auth.sessionId);
    response.status(204).end();
  });

  app.patch('/api/users/me', authenticate, (request, response) => {
    const nickname = typeof request.body.nickname === 'string'
      ? request.body.nickname.trim()
      : request.auth.user.nickname;
    const country = typeof request.body.country === 'string'
      ? request.body.country.trim().toUpperCase()
      : request.auth.user.country;
    const favoriteGenres = request.body.favoriteGenres ?? request.auth.user.favoriteGenres;

    if (nickname.length < 2 || nickname.length > 32) {
      return response.status(400).json({ error: 'Nickname must be between 2 and 32 characters.' });
    }
    if (!/^[A-Z]{2}$/.test(country)) {
      return response.status(400).json({ error: 'Country must be a two-letter code.' });
    }
    if (!Array.isArray(favoriteGenres) || favoriteGenres.length > GENRES.size ||
        favoriteGenres.some((genre) => typeof genre !== 'string' || !GENRES.has(genre))) {
      return response.status(400).json({ error: 'Favorite genres contain an invalid value.' });
    }

    try {
      database.prepare(`
        UPDATE users SET nickname = ?, country = ?, favorite_genres = ? WHERE id = ?
      `).run(nickname, country, JSON.stringify([...new Set(favoriteGenres)]), request.auth.user.id);
    } catch (error) {
      if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return response.status(409).json({ error: 'Nickname is already in use.' });
      }
      throw error;
    }

    const updatedUser = database.prepare('SELECT * FROM users WHERE id = ?')
      .get(request.auth.user.id);
    return response.json({ user: publicUser(updatedUser) });
  });

  for (const [route, kind] of [['watchlist', 'watchlist'], ['favorites', 'favorite']]) {
    app.get(`/api/users/me/${route}`, authenticate, (request, response) => {
      const rows = database.prepare(`
        SELECT movie_id FROM user_movies WHERE user_id = ? AND kind = ? ORDER BY created_at DESC
      `).all(request.auth.user.id, kind);
      response.json({ movieIds: rows.map((row) => row.movie_id) });
    });

    app.put(`/api/users/me/${route}/:movieId`, authenticate, (request, response) => {
      const movieId = request.params.movieId;
      if (!/^\d+$/.test(movieId)) {
        return response.status(400).json({ error: 'Movie ID must be numeric.' });
      }
      database.prepare(`
        INSERT OR IGNORE INTO user_movies (user_id, movie_id, kind, created_at)
        VALUES (?, ?, ?, ?)
      `).run(request.auth.user.id, movieId, kind, new Date().toISOString());
      response.status(204).end();
    });

    app.delete(`/api/users/me/${route}/:movieId`, authenticate, (request, response) => {
      database.prepare(`
        DELETE FROM user_movies WHERE user_id = ? AND movie_id = ? AND kind = ?
      `).run(request.auth.user.id, request.params.movieId, kind);
      response.status(204).end();
    });
  }

  app.get('/api/users/me/actors', authenticate, (request, response) => {
    const rows = database.prepare(`
      SELECT actor_id FROM followed_actors
      WHERE user_id = ? ORDER BY created_at DESC
    `).all(request.auth.user.id);
    return response.json({ actorIds: rows.map((row) => row.actor_id) });
  });

  app.put('/api/users/me/actors/:actorId', authenticate, (request, response) => {
    const actorId = request.params.actorId;
    if (!/^\d+$/.test(actorId)) {
      return response.status(400).json({ error: 'Actor ID must be numeric.' });
    }
    database.prepare(`
      INSERT OR IGNORE INTO followed_actors (user_id, actor_id, created_at)
      VALUES (?, ?, ?)
    `).run(request.auth.user.id, actorId, new Date().toISOString());
    return response.status(204).end();
  });

  app.delete('/api/users/me/actors/:actorId', authenticate, (request, response) => {
    const actorId = request.params.actorId;
    if (!/^\d+$/.test(actorId)) {
      return response.status(400).json({ error: 'Actor ID must be numeric.' });
    }
    database.prepare(
      'DELETE FROM followed_actors WHERE user_id = ? AND actor_id = ?',
    ).run(request.auth.user.id, actorId);
    return response.status(204).end();
  });

  app.get(
    '/api/users/me/recommendation-exclusions',
    authenticate,
    (request, response) => {
      const rows = database.prepare(`
        SELECT movie_id FROM recommendation_exclusions
        WHERE user_id = ?
      `).all(request.auth.user.id);
      return response.json({ movieIds: rows.map((row) => row.movie_id) });
    },
  );

  app.put(
    '/api/users/me/recommendation-exclusions/:movieId',
    authenticate,
    (request, response) => {
      const movieId = request.params.movieId;
      if (!/^\d+$/.test(movieId)) {
        return response.status(400).json({ error: 'Movie ID must be numeric.' });
      }
      database.prepare(`
        INSERT OR IGNORE INTO recommendation_exclusions (user_id, movie_id, created_at)
        VALUES (?, ?, ?)
      `).run(request.auth.user.id, movieId, new Date().toISOString());
      return response.status(204).end();
    },
  );

  function publicReview(row) {
    return {
      id: row.id,
      movieId: row.movie_id,
      userId: row.user_id,
      userNickname: row.nickname,
      rating: row.rating,
      content: row.content,
      containsSpoiler: Boolean(row.contains_spoiler),
      isRewatch: Boolean(row.is_rewatch),
      helpfulCount: row.helpful_count,
      timestamp: row.updated_at,
    };
  }

  function publicViewing(row) {
    return {
      id: row.id,
      movieId: row.movie_id,
      watchedAt: row.watched_at,
      rating: row.rating,
      isRewatch: Boolean(row.is_rewatch),
      notes: row.notes,
    };
  }

  app.get('/api/movies/:movieId/reviews', (request, response) => {
    if (!/^\d+$/.test(request.params.movieId)) {
      return response.status(400).json({ error: 'Movie ID must be numeric.' });
    }
    const rows = database.prepare(`
      SELECT reviews.*, users.nickname
      FROM reviews JOIN users ON users.id = reviews.user_id
      WHERE reviews.movie_id = ?
      ORDER BY reviews.updated_at DESC
    `).all(request.params.movieId);
    response.json({ reviews: rows.map(publicReview) });
  });

  app.get('/api/users/me/reviews', authenticate, (request, response) => {
    const rows = database.prepare(`
      SELECT reviews.*, users.nickname
      FROM reviews JOIN users ON users.id = reviews.user_id
      WHERE reviews.user_id = ?
      ORDER BY reviews.updated_at DESC
    `).all(request.auth.user.id);
    response.json({ reviews: rows.map(publicReview) });
  });

  app.get('/api/users/me/reviews/:movieId', authenticate, (request, response) => {
    const row = database.prepare(`
      SELECT reviews.*, users.nickname
      FROM reviews JOIN users ON users.id = reviews.user_id
      WHERE reviews.user_id = ? AND reviews.movie_id = ?
    `).get(request.auth.user.id, request.params.movieId);
    response.json({ review: row ? publicReview(row) : null });
  });

  app.put('/api/users/me/reviews/:movieId', authenticate, (request, response) => {
    const movieId = request.params.movieId;
    const { rating, content, containsSpoiler, isRewatch } = request.body;
    if (!/^\d+$/.test(movieId) || typeof rating !== 'number' ||
        !Number.isFinite(rating) || rating < 0.5 || rating > 5 ||
        typeof content !== 'string' || content.trim().length === 0 ||
        content.trim().length > 3000 ||
        (containsSpoiler !== undefined && typeof containsSpoiler !== 'boolean') ||
        (isRewatch !== undefined && typeof isRewatch !== 'boolean')) {
      return response.status(400).json({ error: 'Review details are invalid.' });
    }

    const userId = request.auth.user.id;
    const existing = database.prepare(
      'SELECT id FROM reviews WHERE user_id = ? AND movie_id = ?',
    ).get(userId, movieId);
    const id = existing?.id || randomUUID();
    const now = new Date().toISOString();
    database.prepare(`
      INSERT INTO reviews (
        id, user_id, movie_id, rating, content, contains_spoiler,
        is_rewatch, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(user_id, movie_id) DO UPDATE SET
        rating = excluded.rating,
        content = excluded.content,
        contains_spoiler = excluded.contains_spoiler,
        is_rewatch = excluded.is_rewatch,
        updated_at = excluded.updated_at
    `).run(
      id,
      userId,
      movieId,
      rating,
      content.trim(),
      Number(containsSpoiler === true),
      Number(isRewatch === true),
      now,
      now,
    );

    const review = database.prepare(`
      SELECT reviews.*, users.nickname
      FROM reviews JOIN users ON users.id = reviews.user_id
      WHERE reviews.id = ?
    `).get(id);
    return response.status(existing ? 200 : 201).json({ review: publicReview(review) });
  });

  app.delete('/api/users/me/reviews/:reviewId', authenticate, (request, response) => {
    const result = database.prepare(
      'DELETE FROM reviews WHERE id = ? AND user_id = ?',
    ).run(request.params.reviewId, request.auth.user.id);
    if (result.changes === 0) {
      return response.status(404).json({ error: 'Review not found.' });
    }
    return response.status(204).end();
  });

  app.post('/api/reviews/:reviewId/helpful', authenticate, (request, response) => {
    const review = database.prepare(
      'SELECT user_id FROM reviews WHERE id = ?',
    ).get(request.params.reviewId);
    if (!review) return response.status(404).json({ error: 'Review not found.' });
    if (review.user_id === request.auth.user.id) {
      return response.status(400).json({ error: 'You cannot vote on your own review.' });
    }
    database.prepare(`
      INSERT OR IGNORE INTO review_helpful_votes (review_id, user_id, created_at)
      VALUES (?, ?, ?)
    `).run(request.params.reviewId, request.auth.user.id, new Date().toISOString());
    database.prepare(`
      UPDATE reviews SET helpful_count = (
        SELECT COUNT(*) FROM review_helpful_votes WHERE review_id = ?
      ) WHERE id = ?
    `).run(request.params.reviewId, request.params.reviewId);
    const row = database.prepare(
      'SELECT helpful_count FROM reviews WHERE id = ?',
    ).get(request.params.reviewId);
    return response.json({ helpfulCount: row.helpful_count });
  });

  app.get('/api/users/me/journal', authenticate, (request, response) => {
    const rows = database.prepare(`
      SELECT id, movie_id, watched_at, rating, is_rewatch, notes
      FROM viewing_entries WHERE user_id = ? ORDER BY watched_at DESC, created_at DESC
    `).all(request.auth.user.id);
    response.json({ entries: rows.map(publicViewing) });
  });

  app.post('/api/users/me/journal', authenticate, (request, response) => {
    const movieId = typeof request.body.movieId === 'string'
      ? request.body.movieId
      : '';
    const watchedAt = typeof request.body.watchedAt === 'string'
      ? request.body.watchedAt
      : '';
    const watchedDate = new Date(watchedAt);
    const rating = request.body.rating;
    const notes = request.body.notes ?? '';
    const isRewatch = request.body.isRewatch ?? false;
    if (!/^\d+$/.test(movieId) || !watchedAt || Number.isNaN(watchedDate.getTime()) ||
        watchedDate.getTime() > Date.now() ||
        (rating !== null && rating !== undefined &&
          (typeof rating !== 'number' || !Number.isFinite(rating) || rating < 0.5 || rating > 5)) ||
        typeof notes !== 'string' || notes.length > 1000 ||
        typeof isRewatch !== 'boolean') {
      return response.status(400).json({ error: 'Viewing details are invalid.' });
    }

    const entry = {
      id: randomUUID(),
      movieId,
      watchedAt: watchedDate.toISOString(),
      rating: rating ?? null,
      isRewatch,
      notes: notes.trim(),
    };
    database.prepare(`
      INSERT INTO viewing_entries (
        id, user_id, movie_id, watched_at, rating, is_rewatch, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      entry.id,
      request.auth.user.id,
      entry.movieId,
      entry.watchedAt,
      entry.rating,
      Number(entry.isRewatch),
      entry.notes,
      new Date().toISOString(),
    );
    return response.status(201).json({ entry });
  });

  app.delete('/api/users/me/journal/:entryId', authenticate, (request, response) => {
    const result = database.prepare(
      'DELETE FROM viewing_entries WHERE id = ? AND user_id = ?',
    ).run(request.params.entryId, request.auth.user.id);
    if (result.changes === 0) {
      return response.status(404).json({ error: 'Viewing entry not found.' });
    }
    return response.status(204).end();
  });

  app.get('/api/users/me/stats', authenticate, (request, response) => {
    const stats = database.prepare(`
      SELECT
        COUNT(DISTINCT movie_id) AS movies_watched,
        COUNT(*) AS viewing_count,
        AVG(rating) AS average_rating
      FROM viewing_entries WHERE user_id = ?
    `).get(request.auth.user.id);
    const reviewCount = database.prepare(
      'SELECT COUNT(*) AS count FROM reviews WHERE user_id = ?',
    ).get(request.auth.user.id).count;
    const savedCounts = database.prepare(`
      SELECT
        SUM(CASE WHEN kind = 'favorite' THEN 1 ELSE 0 END) AS favorites,
        SUM(CASE WHEN kind = 'watchlist' THEN 1 ELSE 0 END) AS watchlist
      FROM user_movies WHERE user_id = ?
    `).get(request.auth.user.id);
    const followedActors = database.prepare(
      'SELECT COUNT(*) AS count FROM followed_actors WHERE user_id = ?',
    ).get(request.auth.user.id).count;
    const monthlyViewings = database.prepare(`
      SELECT substr(watched_at, 1, 7) AS month, COUNT(*) AS count
      FROM viewing_entries
      WHERE user_id = ?
        AND date(watched_at) >= date('now', 'start of month', '-5 months')
      GROUP BY substr(watched_at, 1, 7)
      ORDER BY month
    `).all(request.auth.user.id);
    const user = database.prepare(
      'SELECT favorite_genres FROM users WHERE id = ?',
    ).get(request.auth.user.id);
    response.json({
      stats: {
        moviesWatched: stats.movies_watched,
        viewingCount: stats.viewing_count,
        avgRating: Number(stats.average_rating || 0),
        publishedReviews: reviewCount,
        favorites: savedCounts.favorites || 0,
        watchlist: savedCounts.watchlist || 0,
        followedActors,
        favoriteGenres: JSON.parse(user.favorite_genres),
        monthlyViewings: monthlyViewings.map((row) => ({
          month: row.month,
          count: row.count,
        })),
      },
    });
  });

  function publicForumTopic(row) {
    return {
      id: row.id,
      title: row.title,
      movieId: row.movie_id,
      authorId: row.author_id,
      authorNickname: row.author_nickname,
      replyCount: row.reply_count,
      timestamp: row.created_at,
      isHidden: Boolean(row.is_hidden),
    };
  }

  function publicForumMessage(row) {
    return {
      id: row.id,
      topicId: row.topic_id,
      userId: row.user_id,
      userNickname: row.nickname,
      isModerator: Boolean(row.is_moderator),
      content: row.is_deleted ? '[Message removed by a moderator]' : row.content,
      likeCount: row.like_count,
      timestamp: row.created_at,
      isDeleted: Boolean(row.is_deleted),
    };
  }

  const topicSelect = `
    SELECT forum_topics.*, users.nickname AS author_nickname,
           (SELECT COUNT(*) FROM forum_messages
            WHERE topic_id = forum_topics.id AND is_deleted = 0) AS reply_count
    FROM forum_topics
    JOIN users ON users.id = forum_topics.author_id
  `;

  app.get('/api/forum/topics', authenticate, (request, response) => {
    const movieId = request.query.movieId;
    const rows = movieId
      ? database.prepare(`${topicSelect}
          WHERE forum_topics.is_hidden = 0 AND forum_topics.movie_id = ?
          ORDER BY forum_topics.created_at DESC`).all(movieId)
      : database.prepare(`${topicSelect}
          WHERE forum_topics.is_hidden = 0
          ORDER BY forum_topics.created_at DESC`).all();
    response.json({ topics: rows.map(publicForumTopic) });
  });

  app.post('/api/forum/topics', authenticate, (request, response) => {
    const title = typeof request.body.title === 'string'
      ? request.body.title.trim()
      : '';
    const movieId = request.body.movieId ?? null;
    if (title.length < 5 || title.length > 120 ||
        (movieId !== null && (typeof movieId !== 'string' ||
          !/^\d+$/.test(movieId)))) {
      return response.status(400).json({ error: 'Topic details are invalid.' });
    }
    const restriction = database.prepare(`
      SELECT id FROM forum_restrictions WHERE user_id = ? AND lifted_at IS NULL
      LIMIT 1
    `).get(request.auth.user.id);
    if (restriction) {
      return response.status(403).json({
        error: 'Your forum interactions are restricted by a moderator.',
      });
    }
    const id = randomUUID();
    database.prepare(`
      INSERT INTO forum_topics (id, title, movie_id, author_id, created_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(id, title, movieId, request.auth.user.id, new Date().toISOString());
    const topic = database.prepare(`${topicSelect} WHERE forum_topics.id = ?`)
      .get(id);
    return response.status(201).json({ topic: publicForumTopic(topic) });
  });

  app.get('/api/forum/topics/:topicId', authenticate, (request, response) => {
    const topic = database.prepare(
      `${topicSelect} WHERE forum_topics.id = ? AND forum_topics.is_hidden = 0`,
    ).get(request.params.topicId);
    if (!topic) return response.status(404).json({ error: 'Topic not found.' });
    return response.json({ topic: publicForumTopic(topic) });
  });

  app.get('/api/forum/topics/:topicId/messages', authenticate, (request, response) => {
    const topic = database.prepare(
      'SELECT id FROM forum_topics WHERE id = ? AND is_hidden = 0',
    ).get(request.params.topicId);
    if (!topic) return response.status(404).json({ error: 'Topic not found.' });
    const rows = database.prepare(`
      SELECT forum_messages.*,
             users.nickname,
             users.is_moderator,
             (SELECT COUNT(*) FROM forum_message_likes
              WHERE message_id = forum_messages.id) AS like_count
      FROM forum_messages
      JOIN users ON users.id = forum_messages.user_id
      WHERE forum_messages.topic_id = ?
      ORDER BY forum_messages.created_at ASC
    `).all(request.params.topicId);
    response.json({ messages: rows.map(publicForumMessage) });
  });

  app.post('/api/forum/topics/:topicId/messages', authenticate, (request, response) => {
    const content = typeof request.body.content === 'string'
      ? request.body.content.trim()
      : '';
    if (content.length < 1 || content.length > 2000) {
      return response.status(400).json({ error: 'Message must be 1 to 2,000 characters.' });
    }
    const topic = database.prepare(
      'SELECT id FROM forum_topics WHERE id = ? AND is_hidden = 0',
    ).get(request.params.topicId);
    if (!topic) return response.status(404).json({ error: 'Topic not found.' });
    const userId = request.auth.user.id;
    const restriction = database.prepare(`
      SELECT id FROM forum_restrictions WHERE user_id = ? AND lifted_at IS NULL
      LIMIT 1
    `).get(userId);
    if (restriction) {
      return response.status(403).json({
        error: 'Your forum interactions are restricted by a moderator.',
      });
    }
    const recentMessageCount = database.prepare(`
      SELECT COUNT(*) AS count FROM forum_messages
      WHERE user_id = ? AND created_at >= ?
    `).get(userId, new Date(Date.now() - 60 * 1000).toISOString()).count;
    if (recentMessageCount >= 5) {
      return response.status(429).json({ error: 'You can post at most 5 messages per minute.' });
    }

    const message = {
      id: randomUUID(),
      topicId: request.params.topicId,
      userId,
      userNickname: request.auth.user.nickname,
      isModerator: request.auth.user.isModerator,
      content,
      likeCount: 0,
      timestamp: new Date().toISOString(),
    };
    database.prepare(`
      INSERT INTO forum_messages (id, topic_id, user_id, content, created_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(message.id, message.topicId, message.userId, message.content, message.timestamp);
    return response.status(201).json({ message });
  });

  app.post('/api/forum/messages/:messageId/likes', authenticate, (request, response) => {
    const message = database.prepare(
      'SELECT id FROM forum_messages WHERE id = ? AND is_deleted = 0',
    ).get(request.params.messageId);
    if (!message) return response.status(404).json({ error: 'Message not found.' });
    database.prepare(`
      INSERT OR IGNORE INTO forum_message_likes (message_id, user_id, created_at)
      VALUES (?, ?, ?)
    `).run(request.params.messageId, request.auth.user.id, new Date().toISOString());
    const likeCount = database.prepare(
      'SELECT COUNT(*) AS count FROM forum_message_likes WHERE message_id = ?',
    ).get(request.params.messageId).count;
    return response.json({ likeCount });
  });

  app.post('/api/forum/reports', authenticate, (request, response) => {
    const { targetType, targetId } = request.body;
    const reason = typeof request.body.reason === 'string'
      ? request.body.reason.trim()
      : '';
    if (!['message', 'topic'].includes(targetType) ||
        typeof targetId !== 'string' || targetId.length > 64 ||
        reason.length < 5 || reason.length > 500) {
      return response.status(400).json({ error: 'Report details are invalid.' });
    }
    const target = targetType === 'message'
      ? database.prepare(`
          SELECT id FROM forum_messages WHERE id = ? AND is_deleted = 0
        `).get(targetId)
      : database.prepare(`
          SELECT id FROM forum_topics WHERE id = ? AND is_hidden = 0
        `).get(targetId);
    if (!target) return response.status(404).json({ error: 'Reported content not found.' });

    const reportId = randomUUID();
    try {
      database.prepare(`
        INSERT INTO forum_reports (
          id, target_type, target_id, reporter_id, reason, created_at
        ) VALUES (?, ?, ?, ?, ?, ?)
      `).run(
        reportId,
        targetType,
        targetId,
        request.auth.user.id,
        reason,
        new Date().toISOString(),
      );
    } catch (error) {
      if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return response.status(409).json({ error: 'You already reported this content.' });
      }
      throw error;
    }
    return response.status(201).json({ reportId });
  });

  app.get(
    '/api/forum/moderation/reports',
    authenticate,
    requireModerator,
    (request, response) => {
      const reports = database.prepare(`
        SELECT MIN(r.id) AS id, r.target_type, r.target_id,
               GROUP_CONCAT(r.reason, '; ') AS reason,
               GROUP_CONCAT(reporters.nickname, ', ') AS reporter_nicknames,
               COUNT(*) AS report_count, MAX(r.created_at) AS created_at,
               m.content AS target_excerpt, m.user_id AS target_author_id,
               u.nickname AS target_author_nickname, r.status
        FROM forum_reports r
        JOIN forum_messages m
          ON r.target_type = 'message' AND r.target_id = m.id
        JOIN users u ON u.id = m.user_id
        JOIN users reporters ON reporters.id = r.reporter_id
        GROUP BY r.target_type, r.target_id, r.status
        UNION ALL
        SELECT MIN(r.id) AS id, r.target_type, r.target_id,
               GROUP_CONCAT(r.reason, '; ') AS reason,
               GROUP_CONCAT(reporters.nickname, ', ') AS reporter_nicknames,
               COUNT(*) AS report_count, MAX(r.created_at) AS created_at,
               t.title AS target_excerpt, t.author_id AS target_author_id,
               u.nickname AS target_author_nickname, r.status
        FROM forum_reports r
        JOIN forum_topics t
          ON r.target_type = 'topic' AND r.target_id = t.id
        JOIN users u ON u.id = t.author_id
        JOIN users reporters ON reporters.id = r.reporter_id
        GROUP BY r.target_type, r.target_id, r.status
        ORDER BY created_at DESC
      `).all();
      const restrictions = database.prepare(`
        SELECT forum_restrictions.id, forum_restrictions.user_id,
               forum_restrictions.reason, forum_restrictions.created_at,
               users.nickname
        FROM forum_restrictions
        JOIN users ON users.id = forum_restrictions.user_id
        WHERE forum_restrictions.lifted_at IS NULL
        ORDER BY forum_restrictions.created_at DESC
      `).all();
      return response.json({
        reports: reports.map((row) => ({
          id: row.id,
          targetType: row.target_type,
          targetId: row.target_id,
          targetExcerpt: row.target_excerpt,
          targetAuthorId: row.target_author_id,
          targetAuthorNickname: row.target_author_nickname,
          reporterNicknames: row.reporter_nicknames,
          reason: row.reason,
          reportCount: row.report_count,
          status: row.status,
          timestamp: row.created_at,
        })),
        restrictions: restrictions.map((row) => ({
          id: row.id,
          userId: row.user_id,
          userNickname: row.nickname,
          reason: row.reason,
          timestamp: row.created_at,
        })),
      });
    },
  );

  app.post(
    '/api/forum/moderation/reports/:reportId/action',
    authenticate,
    requireModerator,
    (request, response) => {
      const action = request.body.action;
      if (!['dismiss', 'remove', 'restrict'].includes(action)) {
        return response.status(400).json({ error: 'Moderation action is invalid.' });
      }
      const report = database.prepare(`
        SELECT target_type, target_id FROM forum_reports
        WHERE id = ? AND status = 'pending'
      `).get(request.params.reportId);
      if (!report) return response.status(404).json({ error: 'Pending report not found.' });

      const table = report.target_type === 'message'
        ? 'forum_messages'
        : 'forum_topics';
      const authorColumn = report.target_type === 'message' ? 'user_id' : 'author_id';
      const target = database.prepare(
        `SELECT ${authorColumn} AS author_id FROM ${table} WHERE id = ?`,
      ).get(report.target_id);
      if (!target) return response.status(404).json({ error: 'Reported content not found.' });

      const transaction = database.transaction(() => {
        let status = 'dismissed';
        if (action === 'remove') {
          const hiddenColumn = report.target_type === 'message'
            ? 'is_deleted'
            : 'is_hidden';
          database.prepare(`UPDATE ${table} SET ${hiddenColumn} = 1 WHERE id = ?`)
            .run(report.target_id);
          status = 'removed';
        } else if (action === 'restrict') {
          if (target.author_id === request.auth.user.id) {
            throw Object.assign(new Error('You cannot restrict your own account.'), {
              statusCode: 400,
            });
          }
          const author = database.prepare(
            'SELECT is_moderator FROM users WHERE id = ?',
          ).get(target.author_id);
          if (author?.is_moderator) {
            throw Object.assign(new Error('Moderator accounts cannot be restricted here.'), {
              statusCode: 400,
            });
          }
          const activeRestriction = database.prepare(`
            SELECT id FROM forum_restrictions
            WHERE user_id = ? AND lifted_at IS NULL
          `).get(target.author_id);
          if (!activeRestriction) {
            database.prepare(`
              INSERT INTO forum_restrictions (
                id, user_id, moderator_id, reason, created_at
              ) VALUES (?, ?, ?, ?, ?)
            `).run(
              randomUUID(),
              target.author_id,
              request.auth.user.id,
              `Report ${report.target_type}: ${report.target_id}`,
              new Date().toISOString(),
            );
          }
          status = 'restricted';
        }
        database.prepare(`
          UPDATE forum_reports SET status = ?
          WHERE target_type = ? AND target_id = ? AND status = 'pending'
        `).run(status, report.target_type, report.target_id);
      });
      try {
        transaction();
      } catch (error) {
        if (error.statusCode) {
          return response.status(error.statusCode).json({ error: error.message });
        }
        throw error;
      }
      return response.json({ status: action === 'dismiss' ? 'dismissed' : action });
    },
  );

  app.post(
    '/api/forum/moderation/restrictions/:restrictionId/lift',
    authenticate,
    requireModerator,
    (request, response) => {
      const result = database.prepare(`
        UPDATE forum_restrictions SET lifted_at = ?
        WHERE id = ? AND lifted_at IS NULL
      `).run(new Date().toISOString(), request.params.restrictionId);
      if (result.changes === 0) {
        return response.status(404).json({ error: 'Active restriction not found.' });
      }
      return response.status(204).end();
    },
  );

  function getCustomList(listId) {
    const row = database.prepare(`
      SELECT id, title, movie_ids, is_shared, user_id
      FROM custom_lists WHERE id = ?
    `).get(listId);
    if (!row) return null;
    const members = database.prepare(`
      SELECT users.id, users.nickname, users.email
      FROM custom_list_members
      JOIN users ON users.id = custom_list_members.user_id
      WHERE custom_list_members.list_id = ?
      ORDER BY custom_list_members.created_at
    `).all(listId);
    return {
      id: row.id,
      title: row.title,
      movieIds: JSON.parse(row.movie_ids),
      isShared: Boolean(row.is_shared),
      userId: row.user_id,
      memberIds: members.map((member) => member.id),
      members: members.map((member) => ({
        id: member.id,
        nickname: member.nickname,
        email: member.email,
      })),
    };
  }

  function canAccessList(listId, userId) {
    return Boolean(database.prepare(`
      SELECT 1 FROM custom_lists
      WHERE id = ? AND (
        user_id = ? OR EXISTS (
          SELECT 1 FROM custom_list_members
          WHERE list_id = custom_lists.id AND user_id = ?
        )
      )
    `).get(listId, userId, userId));
  }

  app.get('/api/users/me/lists', authenticate, (request, response) => {
    const rows = database.prepare(`
      SELECT id FROM custom_lists
      WHERE user_id = ? OR id IN (
        SELECT list_id FROM custom_list_members WHERE user_id = ?
      )
      ORDER BY created_at DESC
    `).all(request.auth.user.id, request.auth.user.id);
    response.json({ lists: rows.map((row) => getCustomList(row.id)) });
  });

  app.get('/api/lists/:listId', authenticate, (request, response) => {
    if (!canAccessList(request.params.listId, request.auth.user.id)) {
      return response.status(404).json({ error: 'List not found.' });
    }
    return response.json({ list: getCustomList(request.params.listId) });
  });

  function parseCustomList(request, response) {
    const title = typeof request.body.title === 'string' ? request.body.title.trim() : '';
    const movieIds = request.body.movieIds ?? [];
    if (title.length < 1 || title.length > 80 || !Array.isArray(movieIds) ||
        movieIds.some((id) => typeof id !== 'string' || !/^\d+$/.test(id))) {
      return response.status(400).json({ error: 'List title or movie IDs are invalid.' });
    }
    const list = {
      id: request.params.listId || randomUUID(),
      title,
      userId: request.auth.user.id,
      movieIds,
      isShared: request.body.isShared === true,
    };
    const now = new Date().toISOString();
    if (request.params.listId) {
      const result = database.prepare(`
        UPDATE custom_lists
        SET title = ?, movie_ids = ?, is_shared = ?
        WHERE id = ? AND user_id = ?
      `).run(
        list.title,
        JSON.stringify(list.movieIds),
        Number(list.isShared),
        list.id,
        list.userId,
      );
      if (result.changes === 0) {
        return response.status(404).json({ error: 'List not found.' });
      }
      if (!list.isShared) {
        database.prepare(
          'DELETE FROM custom_list_members WHERE list_id = ?',
        ).run(list.id);
      }
      return response.json({ list: getCustomList(list.id) });
    }

    database.prepare(`
      INSERT INTO custom_lists (id, user_id, title, movie_ids, is_shared, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(
      list.id,
      list.userId,
      list.title,
      JSON.stringify(list.movieIds),
      Number(list.isShared),
      now,
    );
    return response.status(201).json({ list: getCustomList(list.id) });
  }
  app.post('/api/users/me/lists', authenticate, (request, response) => {
    return parseCustomList(request, response);
  });
  app.put('/api/users/me/lists/:listId', authenticate, (request, response) => {
    return parseCustomList(request, response);
  });

  app.delete('/api/users/me/lists/:listId', authenticate, (request, response) => {
    const result = database.prepare(
      'DELETE FROM custom_lists WHERE id = ? AND user_id = ?',
    ).run(request.params.listId, request.auth.user.id);
    if (result.changes === 0) {
      return response.status(404).json({ error: 'List not found.' });
    }
    response.status(204).end();
  });

  app.post(
    '/api/users/me/lists/:listId/invitations',
    authenticate,
    (request, response) => {
      const email = typeof request.body.email === 'string'
        ? request.body.email.trim().toLowerCase()
        : '';
      const list = database.prepare(
        'SELECT id, is_shared FROM custom_lists WHERE id = ? AND user_id = ?',
      ).get(request.params.listId, request.auth.user.id);
      if (!list) return response.status(404).json({ error: 'List not found.' });
      if (!list.is_shared) {
        return response.status(400).json({ error: 'Enable sharing before inviting members.' });
      }
      if (!EMAIL_PATTERN.test(email) || email.length > 254) {
        return response.status(400).json({ error: 'Enter a valid account email.' });
      }
      const invitee = database.prepare(
        'SELECT id, email, nickname FROM users WHERE email = ?',
      ).get(email);
      if (!invitee) {
        return response.status(404).json({ error: 'No account exists for this email.' });
      }
      if (invitee.id === request.auth.user.id) {
        return response.status(400).json({ error: 'You already own this list.' });
      }
      database.prepare(`
        INSERT OR IGNORE INTO custom_list_members (
          list_id, user_id, invited_by, created_at
        ) VALUES (?, ?, ?, ?)
      `).run(
        list.id,
        invitee.id,
        request.auth.user.id,
        new Date().toISOString(),
      );
      return response.status(201).json({
        member: {
          id: invitee.id,
          nickname: invitee.nickname,
          email: invitee.email,
        },
      });
    },
  );

  app.delete(
    '/api/users/me/lists/:listId/members/:memberId',
    authenticate,
    (request, response) => {
      const result = database.prepare(`
        DELETE FROM custom_list_members
        WHERE list_id = ? AND user_id = ? AND list_id IN (
          SELECT id FROM custom_lists WHERE user_id = ?
        )
      `).run(request.params.listId, request.params.memberId, request.auth.user.id);
      if (result.changes === 0) {
        return response.status(404).json({ error: 'List member not found.' });
      }
      return response.status(204).end();
    },
  );

  app.delete(
    '/api/users/me/lists/:listId/leave',
    authenticate,
    (request, response) => {
      const result = database.prepare(`
        DELETE FROM custom_list_members
        WHERE list_id = ? AND user_id = ?
      `).run(request.params.listId, request.auth.user.id);
      if (result.changes === 0) {
        return response.status(404).json({ error: 'Shared list membership not found.' });
      }
      return response.status(204).end();
    },
  );

  app.put(
    '/api/lists/:listId/movies/:movieId',
    authenticate,
    (request, response) => {
      const { listId, movieId } = request.params;
      if (!/^\d+$/.test(movieId)) {
        return response.status(400).json({ error: 'Movie ID must be numeric.' });
      }
      if (!canAccessList(listId, request.auth.user.id)) {
        return response.status(404).json({ error: 'List not found.' });
      }
      const list = getCustomList(listId);
      if (!list.isShared) {
        return response.status(403).json({ error: 'This list is not shared.' });
      }
      const movieIds = new Set(list.movieIds);
      movieIds.add(movieId);
      database.prepare('UPDATE custom_lists SET movie_ids = ? WHERE id = ?')
        .run(JSON.stringify([...movieIds]), listId);
      return response.json({ list: getCustomList(listId) });
    },
  );

  app.delete(
    '/api/lists/:listId/movies/:movieId',
    authenticate,
    (request, response) => {
      const { listId, movieId } = request.params;
      if (!canAccessList(listId, request.auth.user.id)) {
        return response.status(404).json({ error: 'List not found.' });
      }
      const list = getCustomList(listId);
      if (!list.isShared) {
        return response.status(403).json({ error: 'This list is not shared.' });
      }
      const movieIds = list.movieIds.filter((id) => id !== movieId);
      database.prepare('UPDATE custom_lists SET movie_ids = ? WHERE id = ?')
        .run(JSON.stringify(movieIds), listId);
      return response.status(204).end();
    },
  );

  app.use((error, request, response, next) => {
    if (response.headersSent) return next(error);
    if (error.message === 'Origin is not allowed by CORS.') {
      return response.status(403).json({ error: 'Origin is not allowed.' });
    }
    if (error instanceof SyntaxError && 'body' in error) {
      return response.status(400).json({ error: 'Request body must be valid JSON.' });
    }
    console.error(error);
    return response.status(500).json({ error: 'Internal server error.' });
  });

  return app;
}

module.exports = { createApp };
