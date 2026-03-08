'use client'

import { useState, useEffect, useRef } from 'react'
import { ChatMessage } from '@/components/molecules/ChatMessage'
import { Button } from '@/components/atoms/Button'
import { Input } from '@/components/atoms/Input'
import { ChatWindowProps } from './types'

export function ChatWindow({
  userId,
  otherUser,
  messages,
  onSendMessage,
  onMarkAsRead,
}: ChatWindowProps) {
  const [message, setMessage] = useState('')
  const [isSending, setIsSending] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  useEffect(() => {
    // Marcar mensajes no leídos como leídos
    messages
      .filter((m) => m.senderId !== userId && !m.isRead)
      .forEach((m) => onMarkAsRead?.(m.id))
  }, [messages, userId, onMarkAsRead])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!message.trim()) return

    setIsSending(true)
    try {
      await onSendMessage(message)
      setMessage('')
    } catch (error) {
      console.error('Error al enviar mensaje:', error)
    } finally {
      setIsSending(false)
    }
  }

  return (
    <div className="flex flex-col h-full bg-white rounded-lg shadow-md">
      {/* Header */}
      <div className="p-4 border-b flex items-center gap-3">
        <h2 className="font-semibold text-lg">
          {otherUser.name || otherUser.username || 'Usuario'}
        </h2>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4">
        {messages.length === 0 ? (
          <div className="text-center text-gray-500 mt-8">
            No hay mensajes aún. ¡Comienza la conversación!
          </div>
        ) : (
          messages.map((msg) => (
            <ChatMessage
              key={msg.id}
              id={msg.id}
              content={msg.content}
              senderId={msg.senderId}
              currentUserId={userId}
              sender={
                msg.senderId === userId
                  ? { name: 'Tú', username: null, image: null }
                  : otherUser
              }
              mediaUrl={msg.mediaUrl}
              mediaType={msg.mediaType}
              createdAt={msg.createdAt}
              isRead={msg.isRead}
            />
          ))
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <form onSubmit={handleSubmit} className="p-4 border-t">
        <div className="flex gap-2">
          <Input
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Escribe un mensaje..."
            className="flex-1"
          />
          <Button type="submit" disabled={isSending || !message.trim()}>
            {isSending ? 'Enviando...' : 'Enviar'}
          </Button>
        </div>
      </form>
    </div>
  )
}

