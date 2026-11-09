require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { health, ready } = require('./routes/health');

const app = express();
app.use(cors());
app.use(express.json());
app.use((_req, res, next) => {
  res.setHeader('X-Served-By', process.env.HOSTNAME || 'local');
  next();
});
app.use('/health', health);
app.use('/ready', ready);
app.use('/courses', require('./routes/courses'));
app.use('/enrollments', require('./routes/enrollments'));
app.use('/students', require('./routes/students'));
app.use('/load', require('./routes/load'));
app.use('/demo', require('./routes/demo'));

module.exports = app;
