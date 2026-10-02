const express = require('express');
const os = require('os');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

// DB credentials env se aate hain, AWS me ECS inhe Secrets Manager se inject karta hai
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  // RDS PostgreSQL SSL force karta hai, isliye default ON
  ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false },
  max: 10,
  connectionTimeoutMillis: 5000,
});

// Liveness DB se alag: choti DB dikkat se containers restart na hon
app.get('/health', (req, res) => res.status(200).send('ok'));

app.get('/api/info', (req, res) => {
  res.json({ service: 'backend', hostname: os.hostname(), time: new Date().toISOString() });
});

app.get('/api/db-check', async (req, res) => {
  try {
    const r = await pool.query('SELECT NOW() AS now');
    res.json({ db: 'connected', now: r.rows[0].now });
  } catch (e) {
    console.error('db-check failed:', e.message);
    res.status(500).json({ db: 'error', message: e.message });
  }
});

app.get('/api/items', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name, created_at FROM items ORDER BY id DESC LIMIT 50');
    res.json(r.rows);
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ error: 'db error' });
  }
});

app.post('/api/items', async (req, res) => {
  const name = (req.body.name || '').trim();
  if (!name) return res.status(400).json({ error: 'name required' });
  try {
    const r = await pool.query(
      'INSERT INTO items (name) VALUES ($1) RETURNING id, name, created_at',
      [name]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ error: 'db error' });
  }
});

// Table banao, DB abhi ready na ho to retry karo
async function initDb(retries = 10) {
  for (let i = 1; i <= retries; i++) {
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS items (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      console.log('DB ready');
      return;
    } catch (e) {
      console.log(`DB not ready (${i}/${retries}): ${e.message}`);
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
  console.log('DB init failed, app chalti rahegi, /api/db-check se error dikhega');
}

const PORT = parseInt(process.env.PORT || '3000', 10);
app.listen(PORT, '0.0.0.0', () => {
  console.log(`backend listening on ${PORT}`);
  initDb();
});

process.on('SIGTERM', () => {
  console.log('SIGTERM, shutting down');
  pool.end().then(() => process.exit(0));
});
