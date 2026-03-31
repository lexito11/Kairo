'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { usePosts } from '@/hooks/usePosts'
import { BottomNavigation } from '@/components/templates/BottomNavigation'

type PostKind = 'post' | 'testimony' | 'prayer'

const KIND_OPTIONS: { value: PostKind; label: string; hint: string }[] = [
  { value: 'post', label: 'Publicación', hint: 'Comparte lo que quieras con la comunidad.' },
  { value: 'testimony', label: 'Testimonio', hint: 'Historias de fe y vida.' },
  { value: 'prayer', label: 'Petición de oración', hint: 'Pide oración por una situación.' },
]

export default function CreatePostPage() {
  const router = useRouter()
  const { status } = useSession()
  const { createPost } = usePosts()
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [content, setContent] = useState('')
  const [postKind, setPostKind] = useState<PostKind>('post')
  const [isAnonymous, setIsAnonymous] = useState(false)
  const [files, setFiles] = useState<File[]>([])
  const [previews, setPreviews] = useState<{ url: string; type: 'image' | 'video' }[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const pv: { url: string; type: 'image' | 'video' }[] = files.map((f) => ({
      url: URL.createObjectURL(f),
      type: f.type.startsWith('video/') ? 'video' : 'image',
    }))
    setPreviews(pv)
    return () => {
      pv.forEach((p) => URL.revokeObjectURL(p.url))
    }
  }, [files])

  const onFilesSelected = (list: FileList | null) => {
    if (!list?.length) return
    setFiles((prev) => {
      const next = [...prev]
      const max = 12
      for (let i = 0; i < list.length && next.length < max; i++) {
        const f = list[i]
        if (!f.type.startsWith('image/') && !f.type.startsWith('video/')) continue
        next.push(f)
      }
      return next
    })
  }

  const removeFile = (index: number) => {
    setFiles((prev) => prev.filter((_, i) => i !== index))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    const trimmed = content.trim()
    if (!trimmed && files.length === 0) {
      setError('Escribe algo o elige fotos o videos.')
      return
    }
    if (status !== 'authenticated') {
      router.push('/auth/signin')
      return
    }
    setSubmitting(true)
    try {
      const post = await createPost(trimmed, {
        files: files.length ? files : undefined,
        isAnonymous,
        postKind,
      })
      if (post?.isAnonymous) {
        router.push('/profile')
        return
      }
      router.push('/feed')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo publicar.')
    } finally {
      setSubmitting(false)
    }
  }

  if (status === 'unauthenticated') {
    router.replace('/auth/signin')
    return null
  }

  return (
    <div className="min-h-screen bg-white dark:bg-dark-bg pb-28">
      <div className="max-w-md mx-auto">
        <header className="sticky top-0 z-20 flex items-center gap-3 px-4 py-3 border-b border-gray-200 dark:border-dark-border bg-white/95 dark:bg-dark-bg/95 backdrop-blur-md">
          <button
            type="button"
            onClick={() => router.back()}
            className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100 dark:hover:bg-dark-hover text-gray-700 dark:text-gray-300"
            aria-label="Volver"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 className="text-lg font-bold text-gray-900 dark:text-white flex-1">Nueva publicación</h1>
        </header>

        <form onSubmit={handleSubmit} className="px-4 py-5 space-y-6">
          {/* Tipo */}
          <div>
            <p className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-2">¿Qué vas a publicar?</p>
            <div className="flex flex-col gap-2">
              {KIND_OPTIONS.map((opt) => (
                <label
                  key={opt.value}
                  className={`flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                    postKind === opt.value
                      ? 'border-primary-500 bg-primary-500/10 dark:bg-primary-500/15'
                      : 'border-gray-200 dark:border-dark-border hover:border-gray-300 dark:hover:border-gray-600'
                  }`}
                >
                  <input
                    type="radio"
                    name="postKind"
                    value={opt.value}
                    checked={postKind === opt.value}
                    onChange={() => setPostKind(opt.value)}
                    className="mt-1 text-primary-600"
                  />
                  <div>
                    <span className="font-medium text-gray-900 dark:text-white">{opt.label}</span>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{opt.hint}</p>
                  </div>
                </label>
              ))}
            </div>
          </div>

          {/* Anónimo */}
          <div className="rounded-xl border border-gray-200 dark:border-dark-border p-4 bg-gray-50 dark:bg-dark-card/50">
            <label className="flex items-center gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={isAnonymous}
                onChange={(e) => setIsAnonymous(e.target.checked)}
                className="w-5 h-5 rounded border-gray-300 text-primary-600 focus:ring-primary-500"
              />
              <div>
                <span className="font-medium text-gray-900 dark:text-white">Publicación anónima</span>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                  No aparecerá en el feed público. Solo tú la ves en tu perfil, pestaña &quot;Anónimos&quot;.
                </p>
              </div>
            </label>
          </div>

          {/* Texto */}
          <div>
            <label htmlFor="content" className="text-sm font-semibold text-gray-800 dark:text-gray-200">
              Texto
            </label>
            <textarea
              id="content"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="Escribe aquí…"
              rows={6}
              maxLength={12000}
              className="mt-2 w-full rounded-xl border border-gray-200 dark:border-dark-border bg-white dark:bg-dark-card px-4 py-3 text-gray-900 dark:text-white placeholder:text-gray-400 focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none resize-y min-h-[120px]"
            />
            <p className="text-xs text-gray-400 mt-1 text-right">{content.length} / 12000</p>
          </div>

          {/* Medios */}
          <div>
            <p className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-2">Fotos o videos (opcional)</p>
            <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">
              Hasta 12 archivos. Puedes publicar solo texto, solo medios, o ambos.
            </p>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*,video/*"
              multiple
              className="hidden"
              onChange={(e) => onFilesSelected(e.target.files)}
            />
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="w-full py-3 rounded-xl border-2 border-dashed border-gray-300 dark:border-dark-border text-gray-600 dark:text-gray-300 hover:border-primary-500 hover:text-primary-600 dark:hover:text-primary-400 transition-colors text-sm font-medium"
            >
              + Añadir fotos o videos
            </button>
            {previews.length > 0 && (
              <div className="grid grid-cols-3 gap-2 mt-3">
                {previews.map((p, i) => (
                  <div key={i} className="relative aspect-square rounded-lg overflow-hidden bg-dark-hover group">
                    {p.type === 'image' ? (
                      <img src={p.url} alt="" className="w-full h-full object-cover" />
                    ) : (
                      <video src={p.url} className="w-full h-full object-cover" muted playsInline />
                    )}
                    <button
                      type="button"
                      onClick={() => removeFile(i)}
                      className="absolute top-1 right-1 w-7 h-7 rounded-full bg-black/60 text-white text-xs flex items-center justify-center opacity-90 hover:bg-black/80"
                      aria-label="Quitar"
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Reglas breves */}
          <div className="text-xs text-gray-500 dark:text-gray-400 space-y-1 border-t border-gray-100 dark:border-dark-border pt-4">
            <p className="font-medium text-gray-600 dark:text-gray-300">Resumen</p>
            <ul className="list-disc list-inside space-y-0.5">
              <li>Contenido respetuoso y acorde a la comunidad.</li>
              <li>Testimonios y peticiones son etiquetas; el formato es el mismo (texto y/o medios).</li>
              <li>Anónimo: no sale en el feed general; solo en tu perfil.</li>
            </ul>
          </div>

          {error && (
            <div className="text-sm text-red-600 dark:text-red-400 bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={submitting || status === 'loading'}
            className="w-full py-3.5 rounded-xl font-semibold text-white bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-primary-500/25 transition-all"
          >
            {submitting ? 'Publicando…' : 'Publicar'}
          </button>
        </form>
      </div>
      <BottomNavigation />
    </div>
  )
}
