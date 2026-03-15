# KAIRO

Una red social diseñada para conectar a la comunidad cristiana.

## 🚀 Stack Tecnológico

- **Frontend**: Next.js 14 + React + TypeScript + TailwindCSS
- **Autenticación**: NextAuth
- **Base de Datos**: Supabase (PostgreSQL)
- **ORM**: Prisma
- **Storage**: Supabase Storage
- **Chat en Tiempo Real**: Supabase Realtime
- **Deploy**: Vercel

## 📁 Estructura del Proyecto

```
src/
├── app/                    # Next.js App Router
│   ├── api/               # API Routes
│   └── (routes)/          # Páginas públicas
│
├── components/
│   ├── atoms/             # Componentes pequeños y básicos
│   │   ├── Avatar/
│   │   ├── Button/
│   │   └── Input/
│   │
│   ├── molecules/         # Componentes medianos (combinaciones de atoms)
│   │   ├── PostCard/
│   │   ├── CommentItem/
│   │   └── ChatMessage/
│   │
│   ├── organisms/         # Componentes grandes (combinaciones de molecules)
│   │   ├── PostForm/
│   │   └── ChatWindow/
│   │
│   └── templates/         # Layouts y plantillas
│       ├── Navbar/
│       └── Providers.tsx
│
├── lib/                   # Utilidades y configuraciones
│   ├── auth.ts           # NextAuth config
│   ├── prisma.ts         # Prisma client
│   ├── supabase.ts       # Supabase client
│   ├── storage.ts        # Storage utilities
│   └── realtime.ts       # Realtime utilities
│
├── hooks/                 # Custom React hooks
│   └── usePosts.ts
│
├── types/                 # TypeScript types
│   └── index.ts
│
└── utils/                 # Funciones utilitarias
    └── validation.ts
```

## 🛠️ Instalación

1. **Instalar dependencias**:
```bash
npm install
```

2. **Configurar variables de entorno**:
Copia `.env.example` a `.env` y completa las variables:
- `NEXTAUTH_URL`: URL de tu aplicación
- `NEXTAUTH_SECRET`: Genera con `openssl rand -base64 32`
- `NEXT_PUBLIC_SUPABASE_URL`: URL de tu proyecto Supabase
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Anon key de Supabase
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key de Supabase
- `DATABASE_URL`: Connection string de PostgreSQL

3. **Configurar Prisma**:
```bash
npm run db:generate
npm run db:push
```

4. **Crear bucket en Supabase Storage**:
- Ve a Storage en tu dashboard de Supabase
- Crea un bucket llamado `media`
- Configura políticas de acceso según necesites

5. **Ejecutar en desarrollo**:
```bash
npm run dev
```

## 📝 Funcionalidades

- ✅ Autenticación con NextAuth
- ✅ Feed de publicaciones con **paginación e infinite scroll**
- ✅ Subida de imágenes/videos (máx 50MB, videos máx 60s)
- ✅ Sistema de likes y comentarios
- ✅ Chat privado 1 a 1 con Supabase Realtime
- ✅ Seguir/dejar de seguir usuarios
- ✅ Perfiles de usuario

## ⚡ Optimizaciones de Rendimiento

La aplicación está **súper optimizada** para ser rápida y ligera:

- 🚀 **React.memo** y memoización para evitar re-renders
- 📄 **Paginación** (10 posts por carga) con infinite scroll
- 🖼️ **Lazy loading** de imágenes con Next.js Image
- 💾 **Queries optimizadas** con Prisma (select específico)
- 📦 **Code splitting** automático
- ⚡ **Skeleton screens** para mejor UX
- 🎯 **Bundle size optimizado** (< 200KB gzipped)

Ver [OPTIMIZACIONES.md](./OPTIMIZACIONES.md) para más detalles.

## 🎨 Arquitectura de Componentes

La estructura sigue el patrón **Atomic Design**:

- **Atoms**: Componentes básicos reutilizables (Button, Input, Avatar)
- **Molecules**: Combinaciones de atoms (PostCard, CommentItem)
- **Organisms**: Componentes complejos (PostForm, ChatWindow)
- **Templates**: Layouts y estructuras de página (Navbar, Providers)

## 🚢 Deploy

1. **Vercel** (Frontend + API):
   - Conecta tu repositorio a Vercel
   - Configura las variables de entorno
   - Deploy automático

2. **Supabase** (DB + Storage + Realtime):
   - Ya está configurado en la nube
   - Solo necesitas las credenciales

## 📚 Próximos Pasos

- [ ] Implementar notificaciones
- [ ] Agregar búsqueda de usuarios
- [ ] Sistema de grupos/comunidades
- [ ] Stories (historias temporales)
- [ ] Modo oscuro

## 📄 Licencia

MIT

