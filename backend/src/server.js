require('dotenv').config();

const { createApp } = require('./app');
const { createDatabase } = require('./database');

const database = createDatabase();
const app = createApp({ database });
const port = Number(process.env.PORT || 3000);
const server = app.listen(port, '0.0.0.0', () => {
  console.log(`MovieTracker API listening on port ${port}`);
});

function shutdown() {
  server.close(() => {
    database.close();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
