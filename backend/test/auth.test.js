const { after, before, test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const { createApp } = require('../src/app');
const { createDatabase } = require('../src/database');

const database = createDatabase(':memory:');
const app = createApp({
  database,
  jwtSecret: 'test-secret-with-more-than-thirty-two-characters',
  adminPassword: 'admin',
  passwordHashRounds: 4,
});
let aliceToken;
let aliceId;

after(() => database.close());

test('bootstraps one moderator account with the requested credentials', async () => {
  const admin = await request(app)
    .post('/api/auth/login')
    .send({ email: 'admin@admin.com', password: 'admin' })
    .expect(200);
  assert.equal(admin.body.user.isModerator, true);

  const roles = database.prepare(
    'SELECT COUNT(*) AS count FROM users WHERE is_moderator = 1',
  ).get();
  assert.equal(roles.count, 1);

  await request(app)
    .post('/api/auth/register')
    .send({
      email: 'admin@admin.com',
      password: 'secure-password',
      nickname: 'replacement-admin',
    })
    .expect(409);

  createApp({
    database,
    jwtSecret: 'test-secret-with-more-than-thirty-two-characters',
    adminPassword: 'a-different-password',
    passwordHashRounds: 4,
  });
  await request(app)
    .post('/api/auth/login')
    .send({ email: 'admin@admin.com', password: 'admin' })
    .expect(200);
});

test('registers a user without returning a password hash', async () => {
  const response = await request(app)
    .post('/api/auth/register')
    .send({
      email: 'alice@example.com',
      password: 'secure-password',
      nickname: 'alice',
      country: 'FR',
      favoriteGenres: ['Drama'],
    })
    .expect(201);

  aliceToken = response.body.token;
  aliceId = response.body.user.id;
  assert.ok(aliceToken);
  assert.equal(response.body.user.email, 'alice@example.com');
  assert.equal(response.body.user.isModerator, false);
  assert.equal(response.body.user.favoriteGenres[0], 'Drama');
  assert.equal('password_hash' in response.body.user, false);
});

test('updates profile preferences in the authenticated database account', async () => {
  const updated = await request(app)
    .patch('/api/users/me')
    .set('Authorization', `Bearer ${aliceToken}`)
    .send({
      nickname: 'alice',
      country: 'CA',
      favoriteGenres: ['Drama'],
    })
    .expect(200);
  assert.equal(updated.body.user.nickname, 'alice');
  assert.equal(updated.body.user.country, 'CA');
  assert.deepEqual(updated.body.user.favoriteGenres, ['Drama']);

  const restored = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${aliceToken}`)
    .expect(200);
  assert.equal(restored.body.user.nickname, 'alice');
  assert.equal(restored.body.user.country, 'CA');
  assert.deepEqual(restored.body.user.favoriteGenres, ['Drama']);
});

test('allows Flutter Web on an ephemeral localhost port during preflight', async () => {
  const response = await request(app)
    .options('/api/auth/register')
    .set('Origin', 'http://localhost:50913')
    .set('Access-Control-Request-Method', 'POST')
    .set('Access-Control-Request-Headers', 'content-type')
    .expect(204);

  assert.equal(
    response.headers['access-control-allow-origin'],
    'http://localhost:50913',
  );
});

test('does not allow arbitrary origins through the localhost port rule', async () => {
  await request(app)
    .options('/api/auth/register')
    .set('Origin', 'https://example.com')
    .set('Access-Control-Request-Method', 'POST')
    .set('Access-Control-Request-Headers', 'content-type')
    .expect(403);
});

test('rejects duplicate accounts and invalid passwords', async () => {
  await request(app)
    .post('/api/auth/register')
    .send({
      email: 'alice@example.com',
      password: 'secure-password',
      nickname: 'alice2',
    })
    .expect(409);

  await request(app)
    .post('/api/auth/register')
    .send({
      email: 'bob@example.com',
      password: 'short',
      nickname: 'bob',
    })
    .expect(400);
});

test('signs in, restores the profile, and revokes the session on logout', async () => {
  const login = await request(app)
    .post('/api/auth/login')
    .send({ email: 'ALICE@example.com', password: 'secure-password' })
    .expect(200);
  const token = login.body.token;
  assert.ok(token);

  const profile = await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${token}`)
    .expect(200);
  assert.equal(profile.body.user.id, aliceId);

  await request(app)
    .post('/api/auth/logout')
    .set('Authorization', `Bearer ${token}`)
    .expect(204);

  await request(app)
    .get('/api/auth/me')
    .set('Authorization', `Bearer ${token}`)
    .expect(401);
});

test('user data is authenticated and isolated between accounts', async () => {
  const alice = await request(app)
    .post('/api/auth/login')
    .send({ email: 'alice@example.com', password: 'secure-password' })
    .expect(200);
  aliceToken = alice.body.token;

  await request(app)
    .put('/api/users/me/watchlist/603')
    .set('Authorization', `Bearer ${aliceToken}`)
    .expect(204);

  const aliceList = await request(app)
    .get('/api/users/me/watchlist')
    .set('Authorization', `Bearer ${aliceToken}`)
    .expect(200);
  assert.deepEqual(aliceList.body.movieIds, ['603']);

  const bob = await request(app)
    .post('/api/auth/register')
    .send({
      email: 'bob@example.com',
      password: 'secure-password',
      nickname: 'bob',
    })
    .expect(201);
  const bobList = await request(app)
    .get('/api/users/me/watchlist')
    .set('Authorization', `Bearer ${bob.body.token}`)
    .expect(200);
  assert.deepEqual(bobList.body.movieIds, []);
});

test('followed actors and dismissed recommendations are private and persistent', async () => {
  const alice = await request(app)
    .post('/api/auth/login')
    .send({ email: 'alice@example.com', password: 'secure-password' })
    .expect(200);
  const aliceAuth = { Authorization: `Bearer ${alice.body.token}` };
  const bob = await request(app)
    .post('/api/auth/login')
    .send({ email: 'bob@example.com', password: 'secure-password' })
    .expect(200);
  const bobAuth = { Authorization: `Bearer ${bob.body.token}` };

  await request(app)
    .put('/api/users/me/actors/12345')
    .set(aliceAuth)
    .expect(204);
  await request(app)
    .put('/api/users/me/actors/12345')
    .set(aliceAuth)
    .expect(204);
  const aliceActors = await request(app)
    .get('/api/users/me/actors')
    .set(aliceAuth)
    .expect(200);
  assert.deepEqual(aliceActors.body.actorIds, ['12345']);
  const bobActors = await request(app)
    .get('/api/users/me/actors')
    .set(bobAuth)
    .expect(200);
  assert.deepEqual(bobActors.body.actorIds, []);

  await request(app)
    .put('/api/users/me/recommendation-exclusions/550')
    .set(aliceAuth)
    .expect(204);
  const aliceExclusions = await request(app)
    .get('/api/users/me/recommendation-exclusions')
    .set(aliceAuth)
    .expect(200);
  assert.deepEqual(aliceExclusions.body.movieIds, ['550']);
  const bobExclusions = await request(app)
    .get('/api/users/me/recommendation-exclusions')
    .set(bobAuth)
    .expect(200);
  assert.deepEqual(bobExclusions.body.movieIds, []);

  await request(app)
    .delete('/api/users/me/actors/12345')
    .set(aliceAuth)
    .expect(204);
  const afterUnfollow = await request(app)
    .get('/api/users/me/actors')
    .set(aliceAuth)
    .expect(200);
  assert.deepEqual(afterUnfollow.body.actorIds, []);

  await request(app)
    .put('/api/users/me/actors/not-a-number')
    .set(aliceAuth)
    .expect(400);
  await request(app)
    .put('/api/users/me/recommendation-exclusions/not-a-number')
    .set(aliceAuth)
    .expect(400);
});

test('custom lists can be updated only by their owner', async () => {
  const aliceList = await request(app)
    .post('/api/users/me/lists')
    .set('Authorization', `Bearer ${aliceToken}`)
    .send({ title: 'Weekend', movieIds: ['603'], isShared: false })
    .expect(201);
  const listId = aliceList.body.list.id;

  await request(app)
    .put(`/api/users/me/lists/${listId}`)
    .set('Authorization', `Bearer ${aliceToken}`)
    .send({ title: 'Weekend picks', movieIds: ['603', '550'] })
    .expect(200);

  const bob = await request(app)
    .post('/api/auth/login')
    .send({ email: 'bob@example.com', password: 'secure-password' })
    .expect(200);
  await request(app)
    .put(`/api/users/me/lists/${listId}`)
    .set('Authorization', `Bearer ${bob.body.token}`)
    .send({ title: 'Stolen list', movieIds: [] })
    .expect(404);
});

test('shared lists are visible to invitees and editable only by list members', async () => {
  const alice = await request(app)
    .post('/api/auth/login')
    .send({ email: 'alice@example.com', password: 'secure-password' })
    .expect(200);
  const aliceAuth = { Authorization: `Bearer ${alice.body.token}` };
  const created = await request(app)
    .post('/api/users/me/lists')
    .set(aliceAuth)
    .send({
      title: 'Weekend cinema',
      movieIds: ['603'],
      isShared: true,
    })
    .expect(201);
  const listId = created.body.list.id;

  await request(app)
    .post(`/api/users/me/lists/${listId}/invitations`)
    .set(aliceAuth)
    .send({ email: 'bob@example.com' })
    .expect(201);

  const bob = await request(app)
    .post('/api/auth/login')
    .send({ email: 'bob@example.com', password: 'secure-password' })
    .expect(200);
  const bobAuth = { Authorization: `Bearer ${bob.body.token}` };
  const bobLists = await request(app)
    .get('/api/users/me/lists')
    .set(bobAuth)
    .expect(200);
  assert.equal(bobLists.body.lists.length, 1);
  assert.deepEqual(bobLists.body.lists[0].movieIds, ['603']);
  assert.equal(bobLists.body.lists[0].members[0].email, 'bob@example.com');

  await request(app)
    .post(`/api/users/me/lists/${listId}/invitations`)
    .set(aliceAuth)
    .send({ email: 'not-registered@example.com' })
    .expect(404);

  await request(app)
    .put(`/api/lists/${listId}/movies/550`)
    .set(bobAuth)
    .expect(200);
  const ownerView = await request(app)
    .get(`/api/lists/${listId}`)
    .set(aliceAuth)
    .expect(200);
  assert.deepEqual(ownerView.body.list.movieIds, ['603', '550']);

  await request(app)
    .delete(`/api/users/me/lists/${listId}/leave`)
    .set(bobAuth)
    .expect(204);
  await request(app)
    .get(`/api/lists/${listId}`)
    .set(bobAuth)
    .expect(404);
  await request(app)
    .post(`/api/users/me/lists/${listId}/invitations`)
    .set(aliceAuth)
    .send({ email: 'bob@example.com' })
    .expect(201);

  await request(app)
    .delete(`/api/users/me/lists/${listId}/members/${bob.body.user.id}`)
    .set(bobAuth)
    .expect(404);
  await request(app)
    .delete(`/api/users/me/lists/${listId}/members/${bob.body.user.id}`)
    .set(aliceAuth)
    .expect(204);
  await request(app)
    .get(`/api/lists/${listId}`)
    .set(bobAuth)
    .expect(404);

  const privateList = await request(app)
    .post('/api/users/me/lists')
    .set(aliceAuth)
    .send({ title: 'Private picks', movieIds: [], isShared: false })
    .expect(201);
  await request(app)
    .post(`/api/users/me/lists/${privateList.body.list.id}/invitations`)
    .set(aliceAuth)
    .send({ email: 'bob@example.com' })
    .expect(400);
});

test('journal entries and statistics are persisted per authenticated user', async () => {
  const alice = await request(app)
    .post('/api/auth/login')
    .send({ email: 'alice@example.com', password: 'secure-password' })
    .expect(200);
  const aliceAuth = { Authorization: `Bearer ${alice.body.token}` };

  const entry = await request(app)
    .post('/api/users/me/journal')
    .set(aliceAuth)
    .send({
      movieId: '603',
      watchedAt: '2025-03-01T20:00:00.000Z',
      rating: 4.5,
      isRewatch: true,
      notes: 'A great rewatch',
    })
    .expect(201);
  assert.equal(entry.body.entry.movieId, '603');
  assert.equal(entry.body.entry.rating, 4.5);
  assert.equal(entry.body.entry.isRewatch, true);

  await request(app)
    .post('/api/users/me/journal')
    .set(aliceAuth)
    .send({ movieId: '603', watchedAt: 'not-a-date' })
    .expect(400);

  const list = await request(app)
    .get('/api/users/me/journal')
    .set(aliceAuth)
    .expect(200);
  assert.equal(list.body.entries.length, 1);
  assert.equal(list.body.entries[0].id, entry.body.entry.id);

  const stats = await request(app)
    .get('/api/users/me/stats')
    .set(aliceAuth)
    .expect(200);
  assert.equal(stats.body.stats.moviesWatched, 1);
  assert.equal(stats.body.stats.viewingCount, 1);
  assert.equal(stats.body.stats.avgRating, 4.5);
  assert.equal(stats.body.stats.watchlist, 1);
  assert.equal(stats.body.stats.favorites, 0);
  assert.equal(stats.body.stats.followedActors, 0);
  assert.deepEqual(stats.body.stats.favoriteGenres, ['Drama']);
  assert.ok(Array.isArray(stats.body.stats.monthlyViewings));
  assert.ok(
    stats.body.stats.monthlyViewings.every(
      (month) => /^\d{4}-\d{2}$/.test(month.month) && month.count >= 0,
    ),
  );

  const bob = await request(app)
    .post('/api/auth/login')
    .send({ email: 'bob@example.com', password: 'secure-password' })
    .expect(200);
  const bobList = await request(app)
    .get('/api/users/me/journal')
    .set({ Authorization: `Bearer ${bob.body.token}` })
    .expect(200);
  assert.deepEqual(bobList.body.entries, []);

  await request(app)
    .delete(`/api/users/me/journal/${entry.body.entry.id}`)
    .set({ Authorization: `Bearer ${bob.body.token}` })
    .expect(404);
});

test('reviews are validated, upserted, and isolated by owner', async () => {
  const alice = await request(app)
    .post('/api/auth/login')
    .send({ email: 'alice@example.com', password: 'secure-password' })
    .expect(200);
  const aliceAuth = { Authorization: `Bearer ${alice.body.token}` };

  await request(app)
    .put('/api/users/me/reviews/603')
    .set(aliceAuth)
    .send({ rating: 6, content: 'Invalid rating' })
    .expect(400);

  const created = await request(app)
    .put('/api/users/me/reviews/603')
    .set(aliceAuth)
    .send({
      rating: 4,
      content: 'A timeless film.',
      containsSpoiler: false,
      isRewatch: false,
    })
    .expect(201);
  const reviewId = created.body.review.id;

  const updated = await request(app)
    .put('/api/users/me/reviews/603')
    .set(aliceAuth)
    .send({ rating: 4.5, content: 'A timeless film, even better now.' })
    .expect(200);
  assert.equal(updated.body.review.id, reviewId);
  assert.equal(updated.body.review.rating, 4.5);

  const publicReviews = await request(app)
    .get('/api/movies/603/reviews')
    .expect(200);
  assert.equal(publicReviews.body.reviews.length, 1);
  assert.equal(publicReviews.body.reviews[0].userNickname, 'alice');

  const bob = await request(app)
    .post('/api/auth/login')
    .send({ email: 'bob@example.com', password: 'secure-password' })
    .expect(200);
  const bobAuth = { Authorization: `Bearer ${bob.body.token}` };
  const helpful = await request(app)
    .post(`/api/reviews/${reviewId}/helpful`)
    .set(bobAuth)
    .send({})
    .expect(200);
  assert.equal(helpful.body.helpfulCount, 1);
  const repeatedHelpful = await request(app)
    .post(`/api/reviews/${reviewId}/helpful`)
    .set(bobAuth)
    .send({})
    .expect(200);
  assert.equal(repeatedHelpful.body.helpfulCount, 1);

  await request(app)
    .post(`/api/reviews/${reviewId}/helpful`)
    .set(aliceAuth)
    .send({})
    .expect(400);

  await request(app)
    .delete(`/api/users/me/reviews/${reviewId}`)
    .set(bobAuth)
    .expect(404);
});

test('forum discussions, reports, and reversible restrictions enforce moderator roles', async () => {
  const member = await request(app)
    .post('/api/auth/login')
    .send({ email: 'bob@example.com', password: 'secure-password' })
    .expect(200);
  const memberAuth = { Authorization: `Bearer ${member.body.token}` };

  const topic = await request(app)
    .post('/api/forum/topics')
    .set(memberAuth)
    .send({ title: 'What makes a great science-fiction film?' })
    .expect(201);
  const topicId = topic.body.topic.id;

  const message = await request(app)
    .post(`/api/forum/topics/${topicId}/messages`)
    .set(memberAuth)
    .send({ content: 'Strong characters and thoughtful world building.' })
    .expect(201);
  const messageId = message.body.message.id;

  await request(app)
    .post('/api/forum/reports')
    .set(memberAuth)
    .send({
      targetType: 'message',
      targetId: messageId,
      reason: 'This message violates our community rules.',
    })
    .expect(201);
  await request(app)
    .post('/api/forum/reports')
    .set(memberAuth)
    .send({
      targetType: 'message',
      targetId: messageId,
      reason: 'Second report from same member.',
    })
    .expect(409);

  await request(app)
    .get('/api/forum/moderation/reports')
    .set(memberAuth)
    .expect(403);

  const moderator = await request(app)
    .post('/api/auth/login')
    .send({ email: 'admin@admin.com', password: 'admin' })
    .expect(200);
  assert.equal(moderator.body.user.isModerator, true);
  const moderatorAuth = {
    Authorization: `Bearer ${moderator.body.token}`,
  };
  const queue = await request(app)
    .get('/api/forum/moderation/reports')
    .set(moderatorAuth)
    .expect(200);
  assert.equal(queue.body.reports.length, 1);
  assert.equal(queue.body.reports[0].reportCount, 1);
  assert.equal(queue.body.reports[0].reporterNicknames, 'bob');
  assert.equal(queue.body.reports[0].targetAuthorId, member.body.user.id);

  await request(app)
    .post(`/api/forum/moderation/reports/${queue.body.reports[0].id}/action`)
    .set(moderatorAuth)
    .send({ action: 'restrict' })
    .expect(200);

  await request(app)
    .post(`/api/forum/topics/${topicId}/messages`)
    .set(memberAuth)
    .send({ content: 'I should not be able to reply while restricted.' })
    .expect(403);
  await request(app)
    .post('/api/forum/topics')
    .set(memberAuth)
    .send({ title: 'This topic must also be blocked' })
    .expect(403);

  const activeQueue = await request(app)
    .get('/api/forum/moderation/reports')
    .set(moderatorAuth)
    .expect(200);
  assert.equal(activeQueue.body.restrictions.length, 1);

  await request(app)
    .post(`/api/forum/moderation/restrictions/${activeQueue.body.restrictions[0].id}/lift`)
    .set(moderatorAuth)
    .send({})
    .expect(204);

  await request(app)
    .post(`/api/forum/topics/${topicId}/messages`)
    .set(memberAuth)
    .send({ content: 'I can reply again after the restriction was lifted.' })
    .expect(201);

  const secondReport = await request(app)
    .post('/api/forum/reports')
    .set({ Authorization: `Bearer ${aliceToken}` })
    .send({
      targetType: 'message',
      targetId: messageId,
      reason: 'Please review this content for a policy violation.',
    })
    .expect(201);
  const updatedQueue = await request(app)
    .get('/api/forum/moderation/reports')
    .set(moderatorAuth)
    .expect(200);
  const pendingRemoval = updatedQueue.body.reports.find(
    (report) => report.targetId === messageId,
  );
  assert.ok(pendingRemoval);
  assert.equal(secondReport.body.reportId.length > 0, true);

  await request(app)
    .post(`/api/forum/moderation/reports/${pendingRemoval.id}/action`)
    .set(moderatorAuth)
    .send({ action: 'remove' })
    .expect(200);
  const messages = await request(app)
    .get(`/api/forum/topics/${topicId}/messages`)
    .set(memberAuth)
    .expect(200);
  assert.equal(messages.body.messages[0].isDeleted, true);
  assert.equal(
    messages.body.messages[0].content,
    '[Message removed by a moderator]',
  );
  assert.deepEqual(
    messages.body.messages.map((entry) => entry.isDeleted),
    [true, false],
  );
  const allReports = await request(app)
    .get('/api/forum/moderation/reports')
    .set(moderatorAuth)
    .expect(200);
  assert.deepEqual(
    allReports.body.reports.map((report) => report.status).sort(),
    ['removed', 'restricted'],
  );
});
