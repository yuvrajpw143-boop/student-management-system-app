require('dotenv').config();
const express = require('express'), cors = require('cors'), mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs'), jwt = require('jsonwebtoken');
const app = express(); app.use(cors(), express.json());
const pool = mysql.createPool({ host: process.env.DB_HOST, port: +process.env.DB_PORT || 3306, user: process.env.DB_USER, password: process.env.DB_PASSWORD, database: process.env.DB_NAME });
const h = f => (q, s, n) => f(q, s, n).catch(n);
const bad = m => Object.assign(new Error(m), { status: 400 });
const need = (o, ...k) => k.forEach(x => { if (o[x] === undefined || String(o[x]).trim() === '') throw bad(`${x} is required`); });
const num = (v, x) => { if (isNaN(Number(v))) throw bad(`${x} must be a number`); return Number(v); };
const sign = u => jwt.sign({ id: u.id, name: u.name }, process.env.JWT_SECRET, { expiresIn: '7d' });
const auth = (q, s, n) => { try { q.user = jwt.verify((q.headers.authorization || '').slice(7), process.env.JWT_SECRET); n(); } catch { s.status(401).json({ error: 'Unauthorized' }); } };
const risk = (a, m) => (a < 60 || m < 40) ? 'High' : (a < 75 || m < 55) ? 'Medium' : 'Low';

app.get('/api/health', h(async (q, s) => { await pool.query('SELECT 1'); s.json({ ok: true }); }));

app.post('/api/auth/register', h(async (q, s) => {
  need(q.body, 'name', 'email', 'password');
  if (!/^\S+@\S+\.\S+$/.test(q.body.email)) throw bad('Invalid email');
  if (q.body.password.length < 6) throw bad('Password must be at least 6 characters');
  const [r] = await pool.query('INSERT INTO users(name,email,password_hash) VALUES(?,?,?)', [q.body.name, q.body.email.toLowerCase(), await bcrypt.hash(q.body.password, 10)]);
  const u = { id: r.insertId, name: q.body.name }; s.status(201).json({ token: sign(u), user: u });
}));
app.post('/api/auth/login', h(async (q, s) => {
  need(q.body, 'email', 'password');
  const [[u]] = await pool.query('SELECT * FROM users WHERE email=?', [q.body.email.toLowerCase()]);
  if (!u || !(await bcrypt.compare(q.body.password, u.password_hash))) return s.status(401).json({ error: 'Invalid email or password' });
  s.json({ token: sign(u), user: { id: u.id, name: u.name } });
}));

const list = async (where = '', p = []) => {
  const [rows] = await pool.query(`SELECT s.*,
    COALESCE((SELECT 100*AVG(a.status='present') FROM attendance a WHERE a.student_id=s.id),100) att,
    COALESCE((SELECT AVG(100*m.score/m.max_score) FROM marks m WHERE m.student_id=s.id),100) avg_marks
    FROM students s ${where} ORDER BY s.name`, p);
  return rows.map(r => { r.att = Math.round(r.att); r.avg_marks = Math.round(r.avg_marks); r.risk = risk(r.att, r.avg_marks); return r; });
};
const fields = b => { need(b, 'name', 'roll_no', 'class_name'); return [b.name, b.roll_no, b.class_name, b.email || null, b.phone || null, b.photo_url || null]; };

app.get('/api/students', auth, h(async (q, s) => { const k = `%${q.query.q || ''}%`; s.json(await list('WHERE s.name LIKE ? OR s.roll_no LIKE ? OR s.class_name LIKE ?', [k, k, k])); }));
app.get('/api/students/:id', auth, h(async (q, s) => {
  const [st] = await list('WHERE s.id=?', [q.params.id]); if (!st) return s.status(404).json({ error: 'Student not found' });
  [st.marks] = await pool.query('SELECT m.id,m.exam,m.score,m.max_score,sub.name subject FROM marks m JOIN subjects sub ON sub.id=m.subject_id WHERE m.student_id=? ORDER BY m.id DESC', [q.params.id]);
  s.json(st);
}));
app.post('/api/students', auth, h(async (q, s) => { const [r] = await pool.query('INSERT INTO students(name,roll_no,class_name,email,phone,photo_url) VALUES(?,?,?,?,?,?)', fields(q.body)); s.status(201).json({ id: r.insertId }); }));
app.put('/api/students/:id', auth, h(async (q, s) => { await pool.query('UPDATE students SET name=?,roll_no=?,class_name=?,email=?,phone=?,photo_url=? WHERE id=?', [...fields(q.body), q.params.id]); s.json({ ok: true }); }));
app.delete('/api/students/:id', auth, h(async (q, s) => { await pool.query('DELETE FROM students WHERE id=?', [q.params.id]); s.json({ ok: true }); }));

app.get('/api/attendance', auth, h(async (q, s) => {
  const [r] = await pool.query('SELECT s.id,s.name,s.roll_no,s.photo_url,a.status FROM students s LEFT JOIN attendance a ON a.student_id=s.id AND a.date=? ORDER BY s.name', [q.query.date || new Date().toISOString().slice(0, 10)]); s.json(r);
}));
app.post('/api/attendance', auth, h(async (q, s) => {
  need(q.body, 'student_id', 'date', 'status'); if (!['present', 'absent'].includes(q.body.status)) throw bad('status must be present or absent');
  await pool.query('INSERT INTO attendance(student_id,date,status) VALUES(?,?,?) ON DUPLICATE KEY UPDATE status=VALUES(status)', [q.body.student_id, q.body.date, q.body.status]); s.json({ ok: true });
}));
app.post('/api/marks', auth, h(async (q, s) => {
  need(q.body, 'student_id', 'subject_id', 'exam', 'score'); const sc = num(q.body.score, 'score'), mx = num(q.body.max_score || 100, 'max_score');
  if (sc < 0 || sc > mx) throw bad('score must be between 0 and max_score');
  await pool.query('INSERT INTO marks(student_id,subject_id,exam,score,max_score) VALUES(?,?,?,?,?)', [q.body.student_id, q.body.subject_id, q.body.exam, sc, mx]); s.status(201).json({ ok: true });
}));

app.get('/api/subjects', auth, h(async (q, s) => s.json((await pool.query('SELECT * FROM subjects ORDER BY name'))[0])));
app.post('/api/subjects', auth, h(async (q, s) => { need(q.body, 'name', 'code'); await pool.query('INSERT INTO subjects(name,code) VALUES(?,?)', [q.body.name, q.body.code]); s.status(201).json({ ok: true }); }));
app.delete('/api/subjects/:id', auth, h(async (q, s) => { await pool.query('DELETE FROM subjects WHERE id=?', [q.params.id]); s.json({ ok: true }); }));
app.get('/api/notices', auth, h(async (q, s) => s.json((await pool.query('SELECT * FROM notices ORDER BY id DESC'))[0])));
app.post('/api/notices', auth, h(async (q, s) => { need(q.body, 'title', 'body'); await pool.query('INSERT INTO notices(title,body,created_by) VALUES(?,?,?)', [q.body.title, q.body.body, q.user.id]); s.status(201).json({ ok: true }); }));
app.delete('/api/notices/:id', auth, h(async (q, s) => { await pool.query('DELETE FROM notices WHERE id=?', [q.params.id]); s.json({ ok: true }); }));

app.get('/api/dashboard', auth, h(async (q, s) => {
  const st = await list(); const [[c]] = await pool.query('SELECT (SELECT COUNT(*) FROM subjects) subjects,(SELECT COUNT(*) FROM notices) notices');
  const [notices] = await pool.query('SELECT * FROM notices ORDER BY id DESC LIMIT 3'); const rk = { Low: 0, Medium: 0, High: 0 }; st.forEach(x => rk[x.risk]++);
  const avg = k => st.length ? Math.round(st.reduce((a, x) => a + x[k], 0) / st.length) : 0;
  s.json({ students: st.length, ...c, attendance: avg('att'), avg_marks: avg('avg_marks'), risk: rk, notices });
}));

app.use((q, s) => s.status(404).json({ error: 'Not found' }));
app.use((e, q, s, n) => { const st = e.status || (e.code === 'ER_DUP_ENTRY' ? 409 : 500); if (st === 500) console.error(e); s.status(st).json({ error: e.code === 'ER_DUP_ENTRY' ? 'Duplicate value (already exists)' : st === 500 ? 'Server error' : e.message }); });

(async () => {
  const [[{ n }]] = await pool.query('SELECT COUNT(*) n FROM users');
  if (!n) { await pool.query('INSERT INTO users(name,email,password_hash) VALUES(?,?,?)', ['Admin', 'admin@school.com', await bcrypt.hash('admin123', 10)]); console.log('Demo user created: admin@school.com / admin123'); }
  app.listen(process.env.PORT || 3000, () => console.log('API running on port ' + (process.env.PORT || 3000)));
})().catch(e => { console.error('Startup failed (check DB settings):', e.message); process.exit(1); });
