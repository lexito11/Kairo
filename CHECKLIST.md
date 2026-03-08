# ✅ Checklist de Instalación

Usa este checklist para asegurarte de que todo esté configurado correctamente.

## 📦 Instalación Básica

- [ ] Node.js 18+ instalado
- [ ] `npm install` ejecutado sin errores
- [ ] Todas las dependencias instaladas correctamente

## 🔐 Configuración de Variables de Entorno

- [ ] Archivo `.env` creado (copiado de `.env.example`)
- [ ] `NEXTAUTH_URL` configurado
- [ ] `NEXTAUTH_SECRET` generado y configurado
- [ ] `NEXT_PUBLIC_SUPABASE_URL` configurado
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` configurado
- [ ] `SUPABASE_SERVICE_ROLE_KEY` configurado
- [ ] `DATABASE_URL` configurado con credenciales correctas

## 🗄️ Base de Datos

- [ ] Proyecto Supabase creado
- [ ] `npm run db:generate` ejecutado exitosamente
- [ ] `npm run db:push` ejecutado exitosamente
- [ ] Tablas creadas en la base de datos
- [ ] Prisma Studio funciona (opcional: `npm run db:studio`)

## 📦 Supabase Storage

- [ ] Bucket `media` creado en Supabase
- [ ] Políticas de acceso configuradas
- [ ] Límite de tamaño configurado (50 MB)

## 🚀 Verificación Final

- [ ] `npm run dev` inicia sin errores
- [ ] Servidor corre en `http://localhost:3000`
- [ ] Página principal carga correctamente
- [ ] No hay errores en la consola del navegador
- [ ] No hay errores en la terminal

## 📁 Estructura de Carpetas

- [ ] Carpeta `src/` existe
- [ ] Carpeta `src/components/` con subcarpetas (atoms, molecules, organisms, templates)
- [ ] Carpeta `src/app/` con rutas
- [ ] Carpeta `src/lib/` con utilidades
- [ ] Carpeta `prisma/` con `schema.prisma`

## 🎯 Listo para Programar

- [ ] Todo el checklist anterior completado
- [ ] Documentación leída (README.md, ESTRUCTURA.md)
- [ ] Entiendes la estructura del proyecto
- [ ] **¡Listo para empezar a programar!** 🚀

---

**Si algún paso falla, revisa SETUP.md para solución de problemas.**











