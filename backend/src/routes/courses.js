const express = require('express');
const pool  = require('../db');
const redis = require('../redis');

const router = express.Router();
const POD = process.env.HOSTNAME || 'local';
const CACHE_TTL = 30;

router.get('/', async (_req, res) => {
  try {
    const cached = await redis.get('courses:all').catch(() => null);
    if (cached) {
      return res.json({ data: JSON.parse(cached), source: 'cache', served_by: POD });
    }
    const { rows } = await pool.query(
      `SELECT id, code, name, teacher, credits, capacity, available_slots
       FROM courses ORDER BY name`
    );
    await redis.setex('courses:all', CACHE_TTL, JSON.stringify(rows)).catch(() => {});
    res.json({ data: rows, source: 'db', served_by: POD });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const cached = await redis.get(`course:${id}`).catch(() => null);
    if (cached) {
      return res.json({ data: JSON.parse(cached), source: 'cache', served_by: POD });
    }
    const { rows } = await pool.query(
      `SELECT id, code, name, teacher, credits, capacity, available_slots
       FROM courses WHERE id = $1`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Course not found' });
    await redis.setex(`course:${id}`, CACHE_TTL, JSON.stringify(rows[0])).catch(() => {});
    res.json({ data: rows[0], source: 'db', served_by: POD });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
