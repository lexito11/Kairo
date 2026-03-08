# 📁 Estructura Organizada - Todo Junto

Esta estructura sigue el principio: **"Todo lo relacionado va junto"**

## 🎯 Principio de Organización

Cada componente tiene su propia carpeta con:
- ✅ El componente principal
- ✅ Sus tipos (types.ts)
- ✅ Sus validaciones (validation.ts) - si aplica
- ✅ Sus hooks específicos (hooks.ts) - si aplica
- ✅ Sus componentes hijos/relacionados
- ✅ Sus utilidades (utils.ts) - si aplica

---

## 📂 Estructura Actual

```
src/
├── components/
│   ├── atoms/                    # Componentes básicos
│   │   ├── Avatar/
│   │   │   ├── Avatar.tsx
│   │   │   └── index.ts
│   │   ├── Button/
│   │   │   ├── Button.tsx
│   │   │   └── index.ts
│   │   └── ...
│   │
│   ├── molecules/                # Componentes medianos
│   │   ├── PostCard/            # ⭐ TODO JUNTO
│   │   │   ├── PostCard.tsx     # Componente principal
│   │   │   ├── PostCardSkeleton.tsx  # Componente hijo
│   │   │   ├── types.ts         # Tipos específicos
│   │   │   └── index.ts         # Exports
│   │   │
│   │   ├── ChatMessage/
│   │   │   ├── ChatMessage.tsx
│   │   │   ├── types.ts         # Tipos específicos
│   │   │   └── index.ts
│   │   │
│   │   └── CommentItem/
│   │       ├── CommentItem.tsx
│   │       ├── types.ts         # Tipos específicos
│   │       └── index.ts
│   │
│   ├── organisms/                # Componentes grandes
│   │   ├── PostForm/            # ⭐ TODO JUNTO
│   │   │   ├── PostForm.tsx     # Componente principal
│   │   │   ├── types.ts         # Tipos específicos
│   │   │   ├── validation.ts    # Validaciones específicas
│   │   │   └── index.ts         # Exports
│   │   │
│   │   └── ChatWindow/
│   │       ├── ChatWindow.tsx
│   │       ├── types.ts         # Tipos específicos
│   │       └── index.ts
│   │
│   └── templates/
│       └── ...
│
├── app/
│   └── api/
│       └── posts/               # ⭐ TODO JUNTO
│           ├── route.ts         # Endpoints principales
│           ├── [id]/
│           │   └── like/
│           │       └── route.ts # Endpoint relacionado
│           ├── types.ts         # Tipos de la API
│           └── utils.ts         # Utilidades de la API
│
├── lib/                         # Utilidades globales
├── hooks/                       # Hooks globales
├── types/                       # Types globales
└── utils/                       # Utils globales
```

---

## ✅ Ejemplos de Organización

### 1. PostCard (Molecule)
```
PostCard/
├── PostCard.tsx          # Componente principal
├── PostCardSkeleton.tsx  # Componente hijo (loading state)
├── types.ts              # PostCardProps
└── index.ts              # Exporta todo
```

**Razón**: PostCardSkeleton es específico de PostCard, va junto.

---

### 2. PostForm (Organism)
```
PostForm/
├── PostForm.tsx          # Componente principal
├── types.ts              # PostFormProps, PostFormData
├── validation.ts         # Validaciones específicas
└── index.ts              # Exporta todo
```

**Razón**: Las validaciones son específicas de PostForm, van juntas.

---

### 3. API Posts
```
api/posts/
├── route.ts              # GET y POST principales
├── [id]/
│   └── like/
│       └── route.ts       # Endpoint relacionado
├── types.ts              # Tipos de request/response
└── utils.ts              # Funciones auxiliares
```

**Razón**: Todo lo relacionado con posts API va junto.

---

## 🎯 Reglas de Organización

### ✅ HACER
- ✅ Poner tipos específicos en `ComponentName/types.ts`
- ✅ Poner validaciones en `ComponentName/validation.ts`
- ✅ Poner componentes hijos en la misma carpeta
- ✅ Poner utilidades específicas en `ComponentName/utils.ts`
- ✅ Exportar todo desde `index.ts`

### ❌ NO HACER
- ❌ Poner tipos globales en carpetas de componentes
- ❌ Poner validaciones globales en carpetas de componentes
- ❌ Separar componentes relacionados
- ❌ Duplicar código entre carpetas

---

## 📊 Flujo de Dependencias

```
Componente Principal
    ↓
types.ts (tipos específicos)
    ↓
validation.ts (validaciones específicas) - si aplica
    ↓
ComponenteHijo.tsx (componentes relacionados) - si aplica
    ↓
index.ts (exporta todo)
```

---

## 🔄 Ventajas de Esta Estructura

1. ✅ **Todo relacionado está junto** - Fácil de encontrar
2. ✅ **Fácil de mantener** - Cambios en un lugar
3. ✅ **Fácil de entender** - Estructura clara
4. ✅ **Fácil de escalar** - Agregar nuevos archivos es simple
5. ✅ **Menos imports** - Todo en la misma carpeta
6. ✅ **Mejor organización** - Lógica agrupada

---

## 📝 Notas Importantes

- Los **tipos globales** van en `src/types/`
- Las **utilidades globales** van en `src/utils/`
- Los **hooks globales** van en `src/hooks/`
- Solo los **tipos/utilidades específicos** van en la carpeta del componente

---

**Esta estructura hace que el código sea más mantenible y fácil de entender.** 🚀











