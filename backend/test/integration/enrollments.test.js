// These tests modify ONLY an explicitly selected disposable database and Redis DB.
if (!process.env.DB_NAME?.endsWith('_test') || process.env.ALLOW_TEST_DB_RESET !== 'yes' || process.env.REDIS_DB !== '15') {
  throw new Error('Use DB_NAME=matricula_test, ALLOW_TEST_DB_RESET=yes and REDIS_DB=15 with disposable services.');
}

const fs = require('node:fs');
const path = require('node:path');
const request = require('supertest');
const pool = require('../../src/db');
const redis = require('../../src/redis');
const app = require('../../src/app');

beforeAll(async () => {
  await pool.query(fs.readFileSync(path.join(__dirname, '../../../database/schema.sql'), 'utf8'));
  await redis.ping();
});

beforeEach(async () => {
  await pool.query('TRUNCATE enrollments, courses, students RESTART IDENTITY CASCADE');
  await pool.query("INSERT INTO students (code, name) VALUES ('TEST-1', 'Student One'), ('TEST-2', 'Student Two')");
  await pool.query("INSERT INTO courses (code, name, capacity, available_slots) VALUES ('C1', 'Cloud', 3, 3), ('C2', 'Last slot', 1, 1), ('C3', 'Full', 1, 0)");
  await redis.del('courses:all', 'course:1', 'course:2', 'course:3');
});

afterAll(async () => {
  await pool.end();
  redis.disconnect();
});

const enroll = (student, course) => request(app).post('/enrollments').send({ student_id: student, course_id: course });

test('API is ready with real PostgreSQL', async () => {
  await request(app).get('/ready').expect(200);
});

test('courses are read from PostgreSQL and then cached in real Redis', async () => {
  const first = await request(app).get('/courses').expect(200);
  const second = await request(app).get('/courses').expect(200);
  expect(first.body.source).toBe('db');
  expect(second.body.source).toBe('cache');
  expect(second.body.data).toHaveLength(3);
});

test('a successful enrollment consumes exactly one slot and invalidates cache', async () => {
  await request(app).get('/courses').expect(200);
  await request(app).get('/courses/1').expect(200);
  const response = await enroll(1, 1).expect(201);
  expect(response.body.data.enrollment_id).toBeDefined();
  const course = await request(app).get('/courses/1').expect(200);
  expect(course.body.data.available_slots).toBe(2);
  expect(await redis.get('courses:all')).toBeNull();
  const enrollments = await request(app).get('/enrollments/student/1').expect(200);
  expect(enrollments.body.data).toHaveLength(1);
});

test('a duplicate enrollment returns 409 without consuming another slot', async () => {
  await enroll(1, 1).expect(201);
  await enroll(1, 1).expect(409);
  const result = await pool.query('SELECT available_slots FROM courses WHERE id = 1');
  expect(result.rows[0].available_slots).toBe(2);
  expect((await pool.query('SELECT * FROM enrollments')).rowCount).toBe(1);
});

test('a full course rejects enrollment without inserting a row', async () => {
  await enroll(1, 3).expect(409);
  expect((await pool.query('SELECT * FROM enrollments')).rowCount).toBe(0);
});

test('two simultaneous requests for the last slot produce one success', async () => {
  const responses = await Promise.all([enroll(1, 2), enroll(2, 2)]);
  expect(responses.map((response) => response.status).sort()).toEqual([201, 409]);
  expect((await pool.query('SELECT available_slots FROM courses WHERE id = 2')).rows[0].available_slots).toBe(0);
  expect((await pool.query('SELECT * FROM enrollments WHERE course_id = 2')).rowCount).toBe(1);
});

test('unknown students and courses return 404 and leave slots unchanged', async () => {
  await enroll(999, 1).expect(404);
  await enroll(1, 999).expect(404);
  expect((await pool.query('SELECT available_slots FROM courses WHERE id = 1')).rows[0].available_slots).toBe(3);
});
