const express = require('express');
const pool  = require('../db');
const redis = require('../redis');

const router = express.Router();
const POD = process.env.HOSTNAME || 'local';

router.post('/', async (req, res) => {
  const { student_id, course_id } = req.body;
  if (!student_id || !course_id) {
    return res.status(400).json({ error: 'student_id and course_id are required', served_by: POD });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const courseRes = await client.query(
      'SELECT id, name, available_slots FROM courses WHERE id = $1 FOR UPDATE',
      [course_id]
    );
    if (!courseRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Course not found', served_by: POD });
    }
    const course = courseRes.rows[0];
    if (course.available_slots <= 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'No available slots in this course', served_by: POD });
    }

    const studentRes = await client.query(
      'SELECT id, name FROM students WHERE id = $1',
      [student_id]
    );
    if (!studentRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Student not found', served_by: POD });
    }

    const existingRes = await client.query(
      'SELECT id FROM enrollments WHERE student_id = $1 AND course_id = $2',
      [student_id, course_id]
    );
    if (existingRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Student is already enrolled in this course', served_by: POD });
    }

    const enrollRes = await client.query(
      'INSERT INTO enrollments (student_id, course_id) VALUES ($1, $2) RETURNING id, enrolled_at',
      [student_id, course_id]
    );
    await client.query(
      'UPDATE courses SET available_slots = available_slots - 1 WHERE id = $1',
      [course_id]
    );

    await client.query('COMMIT');

    await redis.del(`course:${course_id}`).catch(() => {});
    await redis.del('courses:all').catch(() => {});

    res.status(201).json({
      data: {
        enrollment_id: enrollRes.rows[0].id,
        student: studentRes.rows[0].name,
        course:  course.name,
        enrolled_at: enrollRes.rows[0].enrolled_at,
      },
      served_by: POD,
    });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    res.status(500).json({ error: err.message, served_by: POD });
  } finally {
    client.release();
  }
});

router.get('/student/:student_id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT e.id, c.id as course_id, c.code, c.name as course_name,
              c.teacher, c.credits, e.enrolled_at
       FROM enrollments e
       JOIN courses c ON e.course_id = c.id
       WHERE e.student_id = $1
       ORDER BY e.enrolled_at DESC`,
      [req.params.student_id]
    );
    res.json({ data: rows, served_by: POD });
  } catch (err) {
    res.status(500).json({ error: err.message, served_by: POD });
  }
});

module.exports = router;
