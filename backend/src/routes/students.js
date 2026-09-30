const express = require('express');
const pool = require('../db');

const router = express.Router();
const POD = process.env.HOSTNAME || 'local';

router.get('/', async (_req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, code, name, email FROM students ORDER BY name'
    );
    res.json({ data: result.rows, served_by: POD });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, code, name, email FROM students WHERE id = $1',
      [req.params.id]
    );
    if (!result.rows.length) return res.status(404).json({ error: 'Student not found' });
    res.json({ data: result.rows[0], served_by: POD });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
