import { z } from 'zod'

export const postSchema = z.object({
  content: z.string().min(1, 'El contenido es requerido').max(5000, 'El contenido es muy largo'),
  file: z.instanceof(File).optional(),
})

export const commentSchema = z.object({
  content: z.string().min(1, 'El comentario es requerido').max(1000, 'El comentario es muy largo'),
})

export const messageSchema = z.object({
  content: z.string().min(1, 'El mensaje es requerido').max(2000, 'El mensaje es muy largo'),
  file: z.instanceof(File).optional(),
})

export function validateFile(file: File): { valid: boolean; error?: string } {
  // Validar tamaño (50 MB)
  if (file.size > 50 * 1024 * 1024) {
    return { valid: false, error: 'El archivo no puede ser mayor a 50 MB' }
  }

  // Validar tipo
  const validTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4', 'video/webm']
  if (!validTypes.includes(file.type)) {
    return { valid: false, error: 'Tipo de archivo no válido' }
  }

  return { valid: true }
}











