# 👀 Cómo Ver el Feed

## 🚀 Pasos para Ver la Aplicación

### 1. **Instalar Dependencias** (Ya hecho ✅)
```bash
npm install
```

### 2. **Iniciar el Servidor de Desarrollo**
```bash
npm run dev
```

### 3. **Abrir en el Navegador**
Una vez que el servidor esté corriendo, verás algo como:
```
✓ Ready in X seconds
○ Local: http://localhost:3000
```

**Abre tu navegador y ve a:**
```
http://localhost:3000
```

O simplemente:
```
http://localhost:3000/feed
```

---

## 📱 Ver en Móvil (Opcional)

Para ver cómo se ve en móvil:

1. **Chrome DevTools:**
   - Presiona `F12` o `Ctrl+Shift+I`
   - Click en el ícono de dispositivo móvil (📱)
   - Selecciona un dispositivo (iPhone, Android, etc.)

2. **O usa tu móvil:**
   - Asegúrate de estar en la misma red WiFi
   - Encuentra la IP de tu computadora
   - Accede desde el móvil: `http://TU_IP:3000`

---

## 🎨 Lo que Verás

- ✅ **Feed con diseño dark mode**
- ✅ **Posts con carrusel de imágenes**
- ✅ **Navegación inferior** (Feed, Explorar, Chat, Perfil)
- ✅ **Botón flotante de crear** (+)
- ✅ **Métricas de engagement** (likes, comentarios, compartir)

---

## ⚠️ Nota Importante

**Para que funcione completamente**, necesitas:

1. **Configurar variables de entorno** (`.env`):
   - NextAuth
   - Supabase
   - Database URL

2. **Configurar la base de datos**:
   ```bash
   npm run db:generate
   npm run db:push
   ```

**Pero puedes ver el diseño y la estructura sin esto** - solo verás datos de ejemplo o mensajes de error si intentas hacer acciones que requieren autenticación.

---

## 🛑 Detener el Servidor

Presiona `Ctrl+C` en la terminal donde está corriendo.

---

**¡Disfruta viendo tu feed!** 🎉











