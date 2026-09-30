const express = require('express');
const crypto = require('crypto');

const router = express.Router();
const POD = process.env.HOSTNAME || 'local';

// Endpoint CPU-bound intencional para una demostracion reproducible del HPA.
// Se limita a 100 ms para evitar bloquear accidentalmente el proceso demasiado tiempo.
router.get('/', (req, res) => {
  const requestedMs = Number.parseInt(req.query.ms || '25', 10);
  const durationMs = Math.min(Math.max(Number.isFinite(requestedMs) ? requestedMs : 25, 5), 100);
  const deadline = Date.now() + durationMs;
  let rounds = 0;
  let value = `${POD}:${Date.now()}`;

  while (Date.now() < deadline) {
    value = crypto.createHash('sha256').update(value).digest('hex');
    rounds += 1;
  }

  res.json({ status: 'completed', duration_ms: durationMs, rounds, served_by: POD });
});

module.exports = router;
