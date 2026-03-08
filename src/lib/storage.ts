import { supabase, createServerClient } from './supabase'

const BUCKET_NAME = 'media'

export async function uploadFile(file: File, path: string): Promise<string> {
  // Validar tamaño (50 MB)
  if (file.size > 50 * 1024 * 1024) {
    throw new Error('El archivo no puede ser mayor a 50 MB')
  }

  const fileExt = file.name.split('.').pop()
  const fileName = `${path}/${Date.now()}.${fileExt}`

  const { data, error } = await supabase.storage
    .from(BUCKET_NAME)
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
    })

  if (error) {
    throw new Error(`Error al subir archivo: ${error.message}`)
  }

  const { data: { publicUrl } } = supabase.storage
    .from(BUCKET_NAME)
    .getPublicUrl(data.path)

  return publicUrl
}

export async function deleteFile(path: string): Promise<void> {
  const { error } = await supabase.storage
    .from(BUCKET_NAME)
    .remove([path])

  if (error) {
    throw new Error(`Error al eliminar archivo: ${error.message}`)
  }
}











