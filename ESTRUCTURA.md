# 📁 Estructura de Carpetas - KAIRO

Esta aplicación sigue el patrón **Atomic Design** organizado por tamaño y complejidad de componentes.

## 🎯 Organización por Tamaño

### **Atoms** (Componentes Pequeños - Básicos)
Componentes fundamentales, indivisibles y reutilizables.

```
src/components/atoms/
├── Avatar/          # Avatar de usuario
│   ├── Avatar.tsx
│   └── index.ts
├── Button/          # Botón reutilizable
│   ├── Button.tsx
│   └── index.ts
└── Input/           # Campo de entrada
    ├── Input.tsx
    └── index.ts
```

**Características:**
- ✅ Componentes pequeños y simples
- ✅ No dependen de otros componentes de UI
- ✅ Altamente reutilizables
- ✅ Props simples y claras

---

### **Molecules** (Componentes Medianos)
Combinaciones de atoms que forman unidades funcionales.

```
src/components/molecules/
├── PostCard/        # Tarjeta de publicación
│   ├── PostCard.tsx
│   └── index.ts
├── CommentItem/     # Item de comentario
│   ├── CommentItem.tsx
│   └── index.ts
└── ChatMessage/     # Mensaje de chat
    ├── ChatMessage.tsx
    └── index.ts
```

**Características:**
- ✅ Combinan 2-3 atoms
- ✅ Tienen funcionalidad específica
- ✅ Pueden tener estado local
- ✅ Reutilizables en diferentes contextos

---

### **Organisms** (Componentes Grandes)
Componentes complejos que combinan molecules y atoms.

```
src/components/organisms/
├── PostForm/        # Formulario de publicación
│   ├── PostForm.tsx
│   └── index.ts
└── ChatWindow/      # Ventana de chat completa
    ├── ChatWindow.tsx
    └── index.ts
```

**Características:**
- ✅ Componentes complejos y completos
- ✅ Combinan múltiples molecules
- ✅ Tienen lógica de negocio
- ✅ Pueden hacer llamadas a API

---

### **Templates** (Layouts y Plantillas)
Estructuras de página y layouts reutilizables.

```
src/components/templates/
├── Navbar/          # Barra de navegación
│   ├── Navbar.tsx
│   └── index.ts
└── Providers.tsx     # Providers de contexto
```

**Características:**
- ✅ Estructuras de página
- ✅ Layouts globales
- ✅ Providers de contexto
- ✅ Configuración de rutas

---

## 📂 Otras Carpetas Importantes

### **lib/** - Utilidades y Configuraciones
```
src/lib/
├── auth.ts          # Configuración NextAuth
├── prisma.ts        # Cliente Prisma
├── supabase.ts      # Cliente Supabase
├── storage.ts       # Utilidades de storage
└── realtime.ts      # Utilidades de tiempo real
```

### **hooks/** - Custom React Hooks
```
src/hooks/
└── usePosts.ts      # Hook para manejar posts
```

### **types/** - TypeScript Types
```
src/types/
├── index.ts         # Types principales
└── next-auth.d.ts   # Types de NextAuth
```

### **utils/** - Funciones Utilitarias
```
src/utils/
└── validation.ts    # Schemas de validación
```

### **app/** - Next.js App Router
```
src/app/
├── api/             # API Routes
│   ├── auth/        # NextAuth routes
│   └── posts/       # Posts API
├── layout.tsx       # Layout raíz
├── page.tsx         # Página principal
└── globals.css      # Estilos globales
```

---

## 🎨 Reglas de Organización

### ✅ **DO (Hacer)**
- Colocar componentes según su tamaño y complejidad
- Usar `index.ts` para exports limpios
- Mantener componentes pequeños y enfocados
- Reutilizar atoms y molecules cuando sea posible

### ❌ **DON'T (No hacer)**
- No mezclar tamaños de componentes
- No crear componentes gigantes
- No duplicar lógica entre componentes
- No poner lógica de negocio en atoms

---

## 📊 Flujo de Componentes

```
Atoms → Molecules → Organisms → Templates → Pages
  ↓         ↓          ↓           ↓         ↓
Button   PostCard   PostForm    Navbar    Feed Page
Avatar   Comment    ChatWindow  Layout    Chat Page
Input    Message    ...         ...       ...
```

---

## 🔄 Ejemplo de Uso

```tsx
// Atom
import { Button } from '@/components/atoms/Button'

// Molecule
import { PostCard } from '@/components/molecules/PostCard'

// Organism
import { PostForm } from '@/components/organisms/PostForm'

// Template
import { Navbar } from '@/components/templates/Navbar'
```

---

## 📝 Notas Importantes

1. **Cada componente tiene su carpeta** con el mismo nombre
2. **index.ts** exporta el componente principal
3. **Props claras y tipadas** con TypeScript
4. **Componentes client-side** usan `'use client'`
5. **Componentes server-side** no necesitan directiva

---

Esta estructura facilita:
- ✅ Mantenimiento del código
- ✅ Escalabilidad del proyecto
- ✅ Reutilización de componentes
- ✅ Colaboración en equipo
- ✅ Testing individual











