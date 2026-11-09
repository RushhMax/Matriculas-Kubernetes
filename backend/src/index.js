const app = require('./app');
const PORT = process.env.PORT || 3000;
const POD  = process.env.HOSTNAME || 'local';

app.listen(PORT, () => {
  console.log(`Backend started | pod=${POD} | port=${PORT}`);
});
