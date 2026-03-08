'use client'

import { useState, useEffect, useRef } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { Avatar } from '@/components/atoms/Avatar'
import { Button } from '@/components/atoms/Button'
import { Comment } from '@/types'

interface CommentsModalProps {
  postId: string
  isOpen: boolean
  onClose: () => void
  onCommentAdded?: () => void
}

export function CommentsModal({ postId, isOpen, onClose, onCommentAdded }: CommentsModalProps) {
  const { data: session } = useSession()
  const router = useRouter()
  const [comments, setComments] = useState<Comment[]>([])
  const [loading, setLoading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [commentContent, setCommentContent] = useState('')
  const commentsEndRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLTextAreaElement>(null)

  const insertEmoji = (emoji: string) => {
    const textarea = inputRef.current
    if (textarea) {
      const start = textarea.selectionStart || 0
      const end = textarea.selectionEnd || 0
      const text = commentContent.substring(0, start) + emoji + commentContent.substring(end)
      setCommentContent(text)
      // Restaurar el cursor después del emoji insertado
      setTimeout(() => {
        textarea.focus()
        textarea.setSelectionRange(start + emoji.length, start + emoji.length)
      }, 0)
    }
  }

  const openEmojiKeyboard = () => {
    const textarea = inputRef.current
    if (textarea) {
      textarea.focus()
      // En móviles, esto puede ayudar a abrir el teclado de emojis
      if (navigator.userAgent.match(/iPhone|iPad|iPod|Android/i)) {
        textarea.setAttribute('inputmode', 'text')
      }
    }
  }

  useEffect(() => {
    if (isOpen && postId) {
      fetchComments()
      // Focus en el input cuando se abre
      setTimeout(() => inputRef.current?.focus(), 100)
    }
  }, [isOpen, postId])

  useEffect(() => {
    if (isOpen) {
      scrollToBottom()
    }
  }, [comments, isOpen])

  const fetchComments = async () => {
    try {
      setLoading(true)
      const response = await fetch(`/api/posts/${postId}/comments`)
      if (response.ok) {
        const data = await response.json()
        setComments(data)
      }
    } catch (error) {
      console.error('Error fetching comments:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!commentContent.trim()) return

    const content = commentContent.trim()

    if (!session?.user?.id) {
      router.push('/auth/signin')
      return
    }

    try {
      setSubmitting(true)
      
      // Crear comentario optimista (aparece inmediatamente)
      const optimisticComment: Comment = {
        id: `temp-${Date.now()}`,
        content,
        createdAt: new Date(),
        updatedAt: new Date(),
        authorId: session.user.id,
        postId: postId,
        author: {
          id: session.user.id,
          name: session.user.name || null,
          username: session.user.email?.split('@')[0] || null,
          image: session.user.image || null,
          email: session.user.email || '',
          bio: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }
      
      // Agregar comentario optimista inmediatamente
      setComments((prev) => [optimisticComment, ...prev])
      setCommentContent('')
      scrollToBottom()
      
      // Guardar en la BD
      const response = await fetch(`/api/posts/${postId}/comments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ content }),
      })

      if (response.ok) {
        const newComment = await response.json()
        
        // Reemplazar el comentario optimista con el real
        setComments((prev) => {
          const filtered = prev.filter(c => c.id !== optimisticComment.id)
          return [newComment, ...filtered]
        })
        
        // Notificar que se agregó un comentario (actualizar contador)
        onCommentAdded?.()
      } else {
        // Si falla, remover el comentario optimista
        setComments((prev) => prev.filter(c => c.id !== optimisticComment.id))
        const error = await response.json()
        alert(error.error || 'Error al agregar comentario')
        setCommentContent(content) // Restaurar el contenido
      }
    } catch (error) {
      console.error('Error adding comment:', error)
      // Remover comentario optimista si hay error
      setComments((prev) => prev.filter(c => !c.id.startsWith('temp-')))
      alert('Error al agregar comentario')
      setCommentContent(content) // Restaurar el contenido
    } finally {
      setSubmitting(false)
    }
  }

  const scrollToBottom = () => {
    commentsEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  if (!isOpen) return null

  const userName = session?.user?.name || session?.user?.email?.split('@')[0] || 'Usuario'

  return (
    <div 
      className={`fixed inset-0 z-50 flex items-end justify-center bg-black/30 backdrop-blur-[2px] transition-opacity duration-300 ${
        isOpen ? 'opacity-100' : 'opacity-0'
      }`}
      onClick={onClose}
    >
      <div 
        className={`bg-dark-card rounded-t-2xl w-full max-w-md flex flex-col shadow-2xl transform transition-transform duration-300 ease-out ${
          isOpen ? 'translate-y-0' : 'translate-y-full'
        }`}
        style={{ maxHeight: 'calc(100vh - 20px)', minHeight: '50vh' }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-center p-4 border-b border-dark-border relative flex-shrink-0">
          <div className="absolute top-3 left-0 right-0 h-1 w-12 mx-auto bg-gray-600 rounded-full"></div>
          <h2 className="text-lg font-semibold text-white">Comentarios</h2>
          <button
            onClick={onClose}
            className="absolute right-4 text-gray-400 hover:text-white transition-colors"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Comments List - Scrollable */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0 scrollbar-hide" style={{ maxHeight: 'calc(100vh - 180px)' }}>
          {loading ? (
            <div className="text-center text-gray-400 py-8">Cargando comentarios...</div>
          ) : comments.length === 0 ? (
            <div className="text-center text-gray-400 py-8 text-sm">No hay comentarios aún. Sé el primero en comentar!</div>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="flex gap-3">
                <Avatar
                  src={comment.author.image}
                  alt={comment.author.name || comment.author.username || 'Usuario'}
                  size="sm"
                />
                <div className="flex-1 min-w-0">
                  <div className="flex items-baseline gap-2 mb-1">
                    <span className="font-semibold text-sm text-white">
                      {comment.author.name || comment.author.username || 'Usuario'}
                    </span>
                    <span className="text-xs text-gray-400">
                      {(() => {
                        const date = new Date(comment.createdAt)
                        const now = new Date()
                        const diffMs = now.getTime() - date.getTime()
                        const diffMins = Math.floor(diffMs / 60000)
                        const diffHours = Math.floor(diffMs / 3600000)
                        const diffDays = Math.floor(diffMs / 86400000)
                        
                        if (diffMins < 1) return 'ahora'
                        if (diffMins < 60) return `hace ${diffMins}m`
                        if (diffHours < 24) return `hace ${diffHours}h`
                        if (diffDays < 7) return `hace ${diffDays}d`
                        return date.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' })
                      })()}
                    </span>
                  </div>
                  <p className="text-sm text-gray-200 whitespace-pre-wrap break-words leading-relaxed">{comment.content}</p>
                </div>
              </div>
            ))
          )}
          <div ref={commentsEndRef} />
        </div>

        {/* Comment Form - Fixed at bottom */}
        <div className="px-4 py-1.5 border-t border-dark-border bg-dark-card flex-shrink-0">
          <form onSubmit={handleSubmit}>
            <div className="flex gap-3 items-center">
              <div className="flex-shrink-0 self-center">
                <Avatar
                  src={session?.user?.image || null}
                  alt={userName}
                  size="sm"
                />
              </div>
              <div className="flex-1 flex items-center gap-2">
                <button
                  type="button"
                  onClick={openEmojiKeyboard}
                  className="flex-shrink-0 text-gray-400 hover:text-white transition-colors"
                  aria-label="Abrir emojis"
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </button>
                <textarea
                  ref={inputRef}
                  value={commentContent}
                  onChange={(e) => setCommentContent(e.target.value)}
                  placeholder="Escribe un comentario..."
                  className="w-full px-4 py-2 bg-dark-card border border-gray-400/30 rounded-full text-white placeholder-gray-400 focus:outline-none focus:border-gray-400/50 resize-none text-sm"
                  rows={1}
                  maxLength={500}
                  inputMode="text"
                  style={{ minHeight: '36px', maxHeight: '100px', lineHeight: '20px' }}
                  onInput={(e) => {
                    const target = e.target as HTMLTextAreaElement
                    target.style.height = 'auto'
                    target.style.height = `${Math.min(target.scrollHeight, 100)}px`
                  }}
                />
              </div>
              <div className="flex-shrink-0 self-center">
                <button
                  type="submit"
                  disabled={submitting || !commentContent.trim()}
                  className={`px-3 py-2 font-semibold text-sm rounded-full transition-colors ${
                    commentContent.trim() && !submitting
                      ? 'text-primary-500 hover:text-primary-400'
                      : 'text-gray-500 cursor-not-allowed'
                  }`}
                >
                  {submitting ? '...' : 'Publicar'}
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}

