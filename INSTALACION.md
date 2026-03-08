# ⚡ Instalación Rápida

## 🚀 Comandos Rápidos

```bash
# 1. Instalar dependencias
npm install

# 2. Configurar variables de entorno
cp .env.example .env
# (Edita .env con tus credenciales)

# 3. Generar Prisma Client
npm run db:generate

# 4. Crear tablas en la base de datos
npm run db:push

# 5. Iniciar servidor de desarrollo
npm run dev
```

## 📝 Variables de Entorno Necesarias

Crea un archivo `.env` con:

```env
# NextAuth
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=genera-con-openssl-rand-base64-32

# Supabase
NEXT_PUBLIC_SUPABASE_URL=tu-url-de-supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu-anon-key
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key

# Database
DATABASE_URL=postgresql://postgres:password@host:5432/postgres
```

## ✅ Checklist

- [ ] `npm install` ✅
- [ ] `.env` configurado ✅
- [ ] `npm run db:generate` ✅
- [ ] `npm run db:push` ✅
- [ ] Bucket `media` creado en Supabase ✅
- [ ] `npm run dev` funciona ✅

**Ver SETUP.md para guía detallada**











