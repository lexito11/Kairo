# 🚀 Guía de Instalación y Setup

Esta guía te ayudará a configurar el proyecto desde cero.

## 📋 Prerrequisitos

Asegúrate de tener instalado:
- **Node.js** 18+ ([Descargar](https://nodejs.org/))
- **npm** o **yarn** (viene con Node.js)
- **Git** (opcional, para control de versiones)

## 🔧 Paso 1: Instalar Dependencias

Abre la terminal en la carpeta del proyecto y ejecuta:

```bash
npm install
```

Esto instalará todas las dependencias necesarias:
- Next.js 14
- React 18
- TypeScript
- Prisma
- TailwindCSS
- NextAuth
- Supabase
- Y más...

**Tiempo estimado:** 2-5 minutos

---

## 🔐 Paso 2: Configurar Variables de Entorno

1. **Copia el archivo de ejemplo:**
   ```bash
   cp .env.example .env
   ```

2. **Abre `.env` y completa las variables:**

### Variables de NextAuth
```env
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=tu-secret-key-aqui
```

**Para generar `NEXTAUTH_SECRET`:**
```bash
# En Windows (Git Bash)
openssl rand -base64 32

# O usa cualquier generador de strings aleatorios
```

### Variables de Supabase

1. Ve a [supabase.com](https://supabase.com) y crea un proyecto
2. En **Settings > API**, copia:
   - `URL` → `NEXT_PUBLIC_SUPABASE_URL`
   - `anon public` → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `service_role` → `SUPABASE_SERVICE_ROLE_KEY` (⚠️ Mantén esto secreto)

```env
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu-anon-key
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key
```

### Variable de Base de Datos

En Supabase, ve a **Settings > Database** y copia la **Connection string**:

```env
DATABASE_URL=postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres
```

Reemplaza `[PASSWORD]` con tu contraseña de base de datos.

---

## 🗄️ Paso 3: Configurar Base de Datos

### 3.1 Generar Cliente de Prisma

```bash
npm run db:generate
```

### 3.2 Crear las Tablas en la Base de Datos

```bash
npm run db:push
```

Esto creará todas las tablas necesarias:
- `users`
- `posts`
- `comments`
- `likes`
- `follows`
- `messages`
- Y más...

### 3.3 (Opcional) Abrir Prisma Studio

Para ver y editar datos visualmente:

```bash
npm run db:studio
```

Se abrirá en `http://localhost:5555`

---

## 📦 Paso 4: Configurar Supabase Storage

1. Ve a tu proyecto en Supabase
2. Ve a **Storage** en el menú lateral
3. Crea un nuevo bucket llamado: **`media`**
4. Configura las políticas:
   - **Public Access**: Habilitado (o configurar políticas específicas)
   - **File size limit**: 50 MB
   - **Allowed MIME types**: `image/*, video/*`

---

## ✅ Paso 5: Verificar que Todo Funciona

### 5.1 Iniciar el Servidor de Desarrollo

```bash
npm run dev
```

Deberías ver:
```
✓ Ready in X seconds
○ Local: http://localhost:3000
```

### 5.2 Abrir en el Navegador

Ve a: **http://localhost:3000**

Deberías ver la página de inicio.

---

## 📁 Estructura de Carpetas (Ya Creada)

```
redSocialCristiana/
├── src/
│   ├── app/              # Next.js App Router
│   │   ├── api/         # API Routes
│   │   ├── feed/        # Página de feed
│   │   └── ...
│   ├── components/      # Componentes React
│   │   ├── atoms/       # Componentes pequeños
│   │   ├── molecules/   # Componentes medianos
│   │   ├── organisms/   # Componentes grandes
│   │   └── templates/   # Layouts
│   ├── lib/             # Utilidades
│   ├── hooks/           # Custom hooks
│   ├── types/           # TypeScript types
│   └── utils/           # Funciones utilitarias
├── prisma/
│   └── schema.prisma    # Schema de base de datos
├── package.json
├── tsconfig.json
├── tailwind.config.ts
└── next.config.js
```

---

## 🎯 Checklist de Instalación

Marca cada paso cuando lo completes:

- [ ] ✅ Node.js instalado
- [ ] ✅ `npm install` ejecutado
- [ ] ✅ Archivo `.env` creado y configurado
- [ ] ✅ Variables de Supabase configuradas
- [ ] ✅ `NEXTAUTH_SECRET` generado
- [ ] ✅ `npm run db:generate` ejecutado
- [ ] ✅ `npm run db:push` ejecutado
- [ ] ✅ Bucket `media` creado en Supabase Storage
- [ ] ✅ `npm run dev` funciona sin errores
- [ ] ✅ Página carga en `http://localhost:3000`

---

## 🐛 Solución de Problemas

### Error: "Missing Supabase environment variables"
- Verifica que `.env` existe y tiene todas las variables
- Reinicia el servidor después de cambiar `.env`

### Error: "Prisma Client not generated"
- Ejecuta: `npm run db:generate`

### Error: "Database connection failed"
- Verifica `DATABASE_URL` en `.env`
- Asegúrate de que la contraseña esté correcta
- Verifica que Supabase esté activo

### Error: "Module not found"
- Ejecuta: `npm install` de nuevo
- Borra `node_modules` y `package-lock.json`, luego `npm install`

### Puerto 3000 ocupado
- Cambia el puerto: `npm run dev -- -p 3001`
- O mata el proceso que usa el puerto 3000

---

## 📚 Próximos Pasos

Una vez que todo esté instalado:

1. **Lee el README.md** para entender la estructura
2. **Revisa ESTRUCTURA.md** para entender la organización de componentes
3. **Lee OPTIMIZACIONES.md** para entender las optimizaciones
4. **Empieza a programar** 🚀

---

## 🆘 ¿Necesitas Ayuda?

- Revisa los archivos de documentación en el proyecto
- Verifica que todas las variables de entorno estén correctas
- Asegúrate de que Supabase esté configurado correctamente

---

**¡Listo para empezar a programar!** 🎉











