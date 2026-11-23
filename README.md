# Sistema de Asistencia con QR

Solo necesitas **Visual Studio Code + GitHub + Supabase**. Sin PHP, sin XAMPP, sin servidor.
Es una página estática (HTML + JS) que habla directo con Supabase, y se publica gratis en GitHub Pages.

## 1. Supabase
1. Abre tu proyecto → **SQL Editor** → pega todo `supabase.sql` → **Run**.
2. **Authentication → Users → Add user → Create new user**: tu correo y contraseña (marca *Auto Confirm User*). Ese será el administrador.
3. **Authentication → Sign In / Providers**: desactiva **Allow new users to sign up** (así nadie más puede crearse cuenta).
4. **Project Settings → API Keys**: copia la clave **Publishable** (o la `anon` si tu panel es el antiguo).
5. En VS Code abre `js/config.js` y pega esa clave en `SUPABASE_KEY`.

> Nunca pegues la clave *secret* / *service_role* en este proyecto. La publishable es pública a propósito; la protección la dan las reglas RLS del SQL.

## 2. Probar en Visual Studio Code
1. Instala la extensión **Live Server** (Ritwick Dey).
2. Clic derecho en `escaner.html` → **Open with Live Server**.
3. Panel admin: `http://127.0.0.1:5500/admin/login.html`.

La cámara funciona en `localhost`/`127.0.0.1` y en HTTPS (GitHub Pages ya es HTTPS).

## 3. GitHub + publicación
```
git init
git add .
git commit -m "Sistema de asistencia QR"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/asistencia-qr.git
git push -u origin main
```
Luego en GitHub: **Settings → Pages → Build and deployment → Deploy from a branch → main / (root) → Save**.
En ~1 minuto tendrás: `https://TU_USUARIO.github.io/asistencia-qr/`

- Escáner (dejar abierto en la entrada): `.../escaner.html`
- Administración: `.../admin/login.html`

## Uso
- Admin → Profesores → registra y usa **Ver QR** para descargar/imprimir el código de cada uno.
- Primer escaneo del día = ingreso; segundo = salida. La hora la pone el servidor (zona Lima), no el celular.
- Horarios y tolerancia: edita la tabla `turnos` en Supabase (Table Editor).

## Cómo está protegido
- Las tablas solo las puede leer/escribir el administrador con sesión iniciada (RLS).
- El escáner no accede a las tablas: solo llama a la función `registrar_asistencia`, que valida el token del QR.
