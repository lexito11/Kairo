'use client'

import { useState, useCallback, useMemo } from 'react'
import Image from 'next/image'
import { Button } from '@/components/atoms/Button'
import { Avatar } from '@/components/atoms/Avatar'
import { useSession } from 'next-auth/react'
import { PostFormProps } from './types'
import { validateFile, validateVideoDuration } from './validation'

export function PostForm({ onSubmit, userImage, userName }: PostFormProps) {
  const { data: session } = useSession()
  const [content, setContent] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleFileChange = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0]
    if (!selectedFile) return

    // Validar archivo
    const fileValidation = validateFile(selectedFile)
    if (!fileValidation.valid) {
      alert(fileValidation.error)
      return
    }

    // Validar duración de video
    const videoValidation = await validateVideoDuration(selectedFile)
    if (!videoValidation.valid) {
      alert(videoValidation.error)
      return
    }

    setFile(selectedFile)
    setPreview(URL.createObjectURL(selectedFile))
  }, [])

  const handleSubmit = useCallback(async (e: React.FormEvent) => {
    e.preventDefault()
    if (!content.trim() && !file) return

    setIsSubmitting(true)
    try {
      await onSubmit({ content, file: file || undefined })
      setContent('')
      setFile(null)
      setPreview(null)
    } catch (error) {
      console.error('Error al crear post:', error)
    } finally {
      setIsSubmitting(false)
    }
  }, [content, file, onSubmit])

  const displayName = useMemo(
    () => userName || session?.user?.name || 'Usuario',
    [userName, session?.user?.name]
  )

  return (
    <form onSubmit={handleSubmit} className="bg-white rounded-lg shadow-md p-6 mb-4">
      <div className="flex gap-3 mb-4">
        <Avatar
          src={userImage || session?.user?.image}
          alt={displayName}
          size="md"
        />
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="¿Qué estás pensando?"
          className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 resize-none"
          rows={4}
        />
      </div>

      {preview && (
        <div className="mb-4 relative">
          {file?.type.startsWith('video/') ? (
            <video
              src={preview}
              controls
              className="w-full max-h-64 rounded-lg"
            />
          ) : (
            <div className="relative">
            <Image
              src={preview}
              alt="Preview"
              width={800}
              height={600}
              className="w-full h-auto max-h-64 object-contain rounded-lg"
              priority
            />
              <button
                type="button"
                onClick={() => {
                  setFile(null)
                  setPreview(null)
                }}
                className="absolute top-2 right-2 bg-red-500 text-white rounded-full w-8 h-8 flex items-center justify-center hover:bg-red-600"
              >
                ×
              </button>
            </div>
          )}
        </div>
      )}

      <div className="flex items-center justify-between">
        <label className="cursor-pointer">
          <input
            type="file"
            accept="image/*,video/*"
            onChange={handleFileChange}
            className="hidden"
          />
          <span className="text-primary-600 hover:text-primary-700 font-medium cursor-pointer">
            📷 Foto/Video
          </span>
        </label>
        <Button type="submit" disabled={isSubmitting || (!content.trim() && !file)}>
          {isSubmitting ? 'Publicando...' : 'Publicar'}
        </Button>
      </div>
    </form>
  )
}

