'use client'

import { useState, useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { Avatar } from '@/components/atoms/Avatar'

interface ShareModalProps {
  postId: string
  isOpen: boolean
  onClose: () => void
}

interface Contact {
  id: string
  name: string | null
  username: string | null
  image: string | null
}

export function ShareModal({ postId, isOpen, onClose }: ShareModalProps) {
  const { data: session } = useSession()
  const [contacts, setContacts] = useState<Contact[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (isOpen && session?.user?.id) {
      fetchContacts()
    }
  }, [isOpen, session?.user?.id])

  const fetchContacts = async () => {
    try {
      setLoading(true)
      const response = await fetch('/api/users/contacts')
      if (response.ok) {
        const data = await response.json()
        setContacts(data)
      }
    } catch (error) {
      console.error('Error fetching contacts:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleShareToContact = async (contactId: string) => {
    // TODO: Implementar compartir a contacto específico
    console.log('Share to contact:', contactId)
    alert('Función de compartir a contacto próximamente')
  }

  const handleShareToSocial = (platform: string) => {
    const postUrl = `${window.location.origin}/feed?post=${postId}`
    const text = 'Mira este post'
    
    const shareUrls: Record<string, string> = {
      whatsapp: `https://wa.me/?text=${encodeURIComponent(text + ' ' + postUrl)}`,
      facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(postUrl)}`,
      twitter: `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(postUrl)}`,
      telegram: `https://t.me/share/url?url=${encodeURIComponent(postUrl)}&text=${encodeURIComponent(text)}`,
      copy: postUrl,
    }

    if (platform === 'copy') {
      navigator.clipboard.writeText(postUrl)
      alert('¡Link copiado al portapapeles!')
      onClose()
    } else if (shareUrls[platform]) {
      window.open(shareUrls[platform], '_blank')
      onClose()
    }
  }

  if (!isOpen) return null

  const getNetworkIcon = (networkId: string) => {
    const icons: Record<string, JSX.Element> = {
      whatsapp: (
        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
          <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/>
        </svg>
      ),
      facebook: (
        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
          <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
        </svg>
      ),
      twitter: (
        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
          <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
        </svg>
      ),
      telegram: (
        <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
          <path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/>
        </svg>
      ),
      copy: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
        </svg>
      ),
    }
    return icons[networkId] || icons.copy
  }

  const socialNetworks = [
    { id: 'whatsapp', name: 'WhatsApp', color: 'bg-[#25D366]' },
    { id: 'facebook', name: 'Facebook', color: 'bg-[#1877F2]' },
    { id: 'twitter', name: 'Twitter', color: 'bg-[#1DA1F2]' },
    { id: 'telegram', name: 'Telegram', color: 'bg-[#0088cc]' },
    { id: 'copy', name: 'Copiar link', color: 'bg-gray-600' },
  ]

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
          <h2 className="text-lg font-semibold text-white">Compartir</h2>
          <button
            onClick={onClose}
            className="absolute right-4 text-gray-400 hover:text-white transition-colors"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Contacts Section */}
        <div className="flex-1 overflow-y-auto p-4 min-h-0 scrollbar-hide" style={{ maxHeight: 'calc(100vh - 300px)' }}>
          <h3 className="text-sm font-semibold text-gray-400 mb-3">Compartir con contactos</h3>
          {loading ? (
            <div className="text-center text-gray-400 py-8">Cargando contactos...</div>
          ) : contacts.length === 0 ? (
            <div className="text-center text-gray-400 py-4 text-sm">
              No tienes contactos aún. ¡Sigue a personas para compartir con ellas!
            </div>
          ) : (
            <div className="space-y-2 mb-6">
              {contacts.map((contact) => (
                <button
                  key={contact.id}
                  onClick={() => handleShareToContact(contact.id)}
                  className="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-dark-hover transition-colors"
                >
                  <Avatar
                    src={contact.image}
                    alt={contact.name || contact.username || 'Contacto'}
                    size="md"
                  />
                  <div className="flex-1 text-left">
                    <p className="text-white font-medium">
                      {contact.name || contact.username || 'Usuario'}
                    </p>
                    {contact.username && contact.name && (
                      <p className="text-gray-400 text-sm">@{contact.username}</p>
                    )}
                  </div>
                </button>
              ))}
            </div>
          )}

          {/* Social Networks Section */}
          <div>
            <h3 className="text-sm font-semibold text-gray-400 mb-3">Compartir en redes sociales</h3>
            <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide">
              {socialNetworks.map((network) => (
                <button
                  key={network.id}
                  onClick={() => handleShareToSocial(network.id)}
                  className={`flex flex-col items-center gap-2 p-4 rounded-xl ${network.color} text-white min-w-[80px] shrink-0 transition-transform hover:scale-105`}
                >
                  <div className="w-6 h-6">{getNetworkIcon(network.id)}</div>
                  <span className="text-xs font-medium text-center">{network.name}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

