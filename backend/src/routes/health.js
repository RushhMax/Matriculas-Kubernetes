const express = require('express');
const pool = require('../db');
const healthState = require('../health-state');

const health = express.Router();
const ready  = express.Router();

const POD = process.env.HOSTNAME || 'local';
const VERSION = process.env.APP_VERSION || 'development';

health.get('/', (_req, res) => {
  if (!healthState.healthy) {
    return res.status(500).json({ status: 'unhealthy', pod: POD, version: VERSION });
  }
  res.json({ status: 'ok', pod: POD, version: VERSION, ts: new Date().toISOString() });
});

ready.get('/', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ready', pod: POD, version: VERSION });
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: err.message, pod: POD });
  }
});

module.exports = { health, ready };
