# EduCon IBERO Tijuana

App de Educación Continua de IBERO Tijuana: diplomados, calendario, profesores, catálogo y precios, vinculación empresarial, pendientes del equipo y datos por completar.

- **Página:** `index.html` (un solo archivo, publicado con GitHub Pages).
- **Datos y acceso:** Supabase (base de datos, inicio de sesión por correo y cambios en vivo).

## Puesta en marcha (una sola vez)

1. **Supabase → SQL Editor:** corre `supabase/1_estructura.sql` y después `supabase/2_datos.sql`.
2. **Supabase → Authentication → Sign In / Providers → Email:** desactiva «Allow new users to sign up», para que solo entre gente invitada.
3. **Supabase → Authentication → URL Configuration:** en *Site URL* y *Redirect URLs* pon la liga de GitHub Pages (por ejemplo `https://usuario.github.io/educon/`).
4. **GitHub → Settings → Pages:** *Deploy from a branch*, rama `main`, carpeta `/ (root)`.

## Dar acceso a alguien

Supabase → Authentication → Users → **Invite user** → su correo. Le llega un correo; después entra a la liga de la app con ese mismo correo y recibe una liga para iniciar sesión. Para quitarle el acceso, borra su usuario.

## Seguridad

- La llave que va en `index.html` es la **anon / public**: está hecha para ir en la página. Los datos solo se pueden leer o cambiar con sesión iniciada (reglas en `1_estructura.sql`).
- La llave **service_role** nunca se pone en este repositorio.
