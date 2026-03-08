import { z } from 'zod'

export const postFormSchema = z.object({
  content: z.string().max(5000, 'El contenido es muy largo'),
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

export async function validateVideoDuration(file: File): Promise<{ valid: boolean; error?: string }> {
  return new Promise((resolve) => {
    if (!file.type.startsWith('video/')) {
      resolve({ valid: true })
      return
    }

    const video = document.createElement('video')
    video.preload = 'metadata'
    video.onloadedmetadata = () => {
      window.URL.revokeObjectURL(video.src)
      if (video.duration > 60) {
        resolve({ valid: false, error: 'El video no puede ser mayor a 60 segundos' })
      } else {
        resolve({ valid: true })
      }
    }
    video.onerror = () => {
      resolve({ valid: false, error: 'Error al validar el video' })
    }
    video.src = URL.createObjectURL(file)
  })
}











