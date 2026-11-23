const TZ = 'America/Lima';
const db = window.supabase.createClient(APP.SUPABASE_URL, APP.SUPABASE_KEY);

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const hoyLima = () => new Date().toLocaleDateString('en-CA', {timeZone: TZ}); // YYYY-MM-DD
const fmtFecha = f => f ? f.split('-').reverse().join('/') : '—';
const horaLima = iso => iso ? new Date(iso).toLocaleTimeString('es-PE', {hour: '2-digit', minute: '2-digit', hour12: false, timeZone: TZ}) : '—';
const tokenNuevo = () => Array.from(crypto.getRandomValues(new Uint8Array(16)), b => b.toString(16).padStart(2, '0')).join('');
const $ = id => document.getElementById(id);

function aviso(el, tipo, texto) { el.className = 'msg ' + tipo; el.textContent = texto; }

async function requireAdmin() {
  const {data: {session}} = await db.auth.getSession();
  if (!session) { location.href = 'login.html'; await new Promise(() => {}); }
  return session;
}

function renderTop(activa) {
  const l = (href, id, txt) => `<a href="${href}" class="${activa === id ? 'on' : ''}">${txt}</a>`;
  $('top').className = 'top';
  $('top').innerHTML = `<strong class="brand">Asistencia docente</strong><nav>
    ${l('index.html', 'inicio', 'Hoy')}${l('profesores.html', 'prof', 'Profesores')}${l('reportes.html', 'rep', 'Reportes')}
    <a href="../escaner.html" target="_blank">Abrir escáner</a><a href="#" id="salir">Salir</a></nav>`;
  $('salir').onclick = async e => { e.preventDefault(); await db.auth.signOut(); location.href = 'login.html'; };
}

/** Asistencias con filtros {desde,hasta,turno,profesor,estado}. Pagina de 1000 en 1000 (límite de Supabase). */
async function buscarAsistencias(f) {
  const build = () => {
    let q = db.from('asistencias').select('*,profesores(dni,nombres,apellidos),turnos(nombre)')
      .order('fecha', {ascending: false}).order('hora_ingreso', {ascending: false});
    if (f.desde) q = q.gte('fecha', f.desde);
    if (f.hasta) q = q.lte('fecha', f.hasta);
    if (f.turno) q = q.eq('turno_id', f.turno);
    if (f.profesor) q = q.eq('profesor_id', f.profesor);
    if (f.estado) q = q.eq('estado', f.estado);
    return q;
  };
  let todo = [];
  for (let desde = 0; desde < 10000; desde += 1000) {
    const {data, error} = await build().range(desde, desde + 999);
    if (error) throw error;
    todo = todo.concat(data);
    if (data.length < 1000) break;
  }
  return todo;
}

const tagEstado = r => `<span class="tag ${esc(r.estado)}">${r.estado === 'tardanza' ? 'Tardanza (' + (+r.minutos_tarde || 0) + ' min)' : 'Puntual'}</span>`;
