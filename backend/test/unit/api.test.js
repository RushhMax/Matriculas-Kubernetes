jest.mock('../../src/db', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../../src/redis', () => ({ get: jest.fn(), setex: jest.fn(), del: jest.fn() }));

const request = require('supertest');
const app = require('../../src/app');
const pool = require('../../src/db');
const redis = require('../../src/redis');
const healthState = require('../../src/health-state');

beforeEach(() => {
  healthState.healthy = true;
  redis.get.mockResolvedValue(null);
  redis.setex.mockResolvedValue('OK');
  pool.query.mockResolvedValue({ rows: [] });
});

test('health reports a live application without requiring the database', async () => {
  const response = await request(app).get('/health').expect(200);
  expect(response.body.status).toBe('ok');
  expect(response.headers['x-served-by']).toBeTruthy();
  expect(pool.query).not.toHaveBeenCalled();
});

test('health returns an error when the demonstration marks the process unhealthy', async () => {
  healthState.healthy = false;
  const response = await request(app).get('/health').expect(500);
  expect(response.body.status).toBe('unhealthy');
});

test('readiness accepts a reachable database', async () => {
  const response = await request(app).get('/ready').expect(200);
  expect(response.body.status).toBe('ready');
});

test('readiness rejects an unavailable database', async () => {
  pool.query.mockRejectedValueOnce(new Error('database unavailable'));
  const response = await request(app).get('/ready').expect(503);
  expect(response.body.status).toBe('not ready');
});

test.each([{}, { student_id: 1 }, { course_id: 1 }])('enrollment rejects missing identifiers: %j', async (body) => {
  await request(app).post('/enrollments').send(body).expect(400);
  expect(pool.connect).not.toHaveBeenCalled();
});

test('enrollment handles a connection failure without leaving the request pending', async () => {
  pool.connect.mockRejectedValueOnce(new Error('connection refused'));
  const response = await request(app).post('/enrollments').send({ student_id: 1, course_id: 1 }).expect(500);
  expect(response.body.error).toBe('connection refused');
});

test('course listing falls back to PostgreSQL when Redis is unavailable', async () => {
  redis.get.mockRejectedValueOnce(new Error('cache unavailable'));
  const courses = [{ id: 1, name: 'Cloud', available_slots: 2 }];
  pool.query.mockResolvedValueOnce({ rows: courses });
  const response = await request(app).get('/courses').expect(200);
  expect(response.body).toMatchObject({ data: courses, source: 'db' });
});

test('course listing can use the cache without querying PostgreSQL', async () => {
  redis.get.mockResolvedValueOnce(JSON.stringify([{ id: 1, available_slots: 2 }]));
  const response = await request(app).get('/courses').expect(200);
  expect(response.body.source).toBe('cache');
  expect(pool.query).not.toHaveBeenCalled();
});

test('an unknown course returns 404', async () => {
  await request(app).get('/courses/999').expect(404);
});
