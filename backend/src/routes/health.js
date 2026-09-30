const express = require('express');
const pool = require('../db');

const health = express.Router();
const ready  = express.Router();

const POD = process.env.HOSTNAME || 'local';

health.get('/', (_req, res) => {
  res.json({ status: 'ok', pod: POD, ts: new Date().toISOString() });
});

ready.get('/', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ready', pod: POD });
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: err.message, pod: POD });
  }
});

module.exports = { health, ready };
