require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const { health, ready } = require('./routes/health');
const coursesRouter     = require('./routes/courses');
const enrollmentsRouter = require('./routes/enrollments');
const studentsRouter    = require('./routes/students');

const app  = express();
const PORT = process.env.PORT || 3000;
const POD  = process.env.HOSTNAME || 'local';

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  res.setHeader('X-Served-By', POD);
  next();
});

app.use('/health',      health);
app.use('/ready',       ready);
app.use('/courses',     coursesRouter);
app.use('/enrollments', enrollmentsRouter);
app.use('/students',    studentsRouter);

app.listen(PORT, () => {
  console.log(`Backend started | pod=${POD} | port=${PORT}`);
});
