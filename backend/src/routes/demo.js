const express = require('express');
const healthState = require('../health-state');

const router = express.Router();
const POD = process.env.HOSTNAME || 'local';

router.post('/fail-health', (_req, res) => {
  if (process.env.DEMO_MODE !== 'true') {
    return res.status(404).json({ error: 'Demo mode is disabled', served_by: POD });
  }
  healthState.healthy = false;
  res.status(202).json({
    status: 'health failure enabled',
    served_by: POD,
    expected: 'liveness probe will restart this container',
  });
});

module.exports = router;
