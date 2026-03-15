'use client'

import { useState, useMemo, useCallback, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { Avatar } from '@/components/atoms/Avatar'
import { BottomNavigation } from '@/components/templates/BottomNavigation'
import { FeelingsSelector } from '@/components/organisms/FeelingsSelector'
import { CommentsModal } from '@/components/organisms/CommentsModal'
import { ShareModal } from '@/components/organisms/ShareModal'
import { PostCard } from '@/components/molecules/PostCard'
import { usePosts } from '@/hooks/usePosts'
import { Post } from '@/types'
import Image from 'next/image'

interface UserStats {
  siguiendo: number
  seguidores: number
  meGusta: number
}

export default function ProfilePage() {
  const router = useRouter()
  const { data: session } = useSession()
  const { posts, likePost, refreshPost } = usePosts()
  const [selectedFeeling, setSelectedFeeling] = useState('')
  const [selectedTab, setSelectedTab] = useState('publicaciones')
  const [selectedMediaIndex, setSelectedMediaIndex] = useState<number | null>(null)
  const [selectedPostForComments, setSelectedPostForComments] = useState<string | null>(null)
  const [selectedPostForShare, setSelectedPostForShare] = useState<string | null>(null)

  // Datos de ejemplo del usuario
  const displayName = 'Alex Perea'
  const displayUsername = '@alex_perea11'
  const userId = session?.user?.id || 'user-1' // ID temporal del usuario
  const searchParams = useSearchParams()
  // Si en la URL viene otro userId (ej. /profile?userId=xxx), es el perfil de otro usuario.
  // Anónimos solo se muestra cuando es tu propio perfil (isProfileOwner).
  const viewedUserId = searchParams.get('userId') || userId
  const isProfileOwner = viewedUserId === userId

  // Si estás viendo el perfil de otro, no mostrar pestaña Anónimos; asegurar tab válido
  useEffect(() => {
    if (!isProfileOwner && selectedTab === 'anonimos') {
      setSelectedTab('publicaciones')
    }
  }, [isProfileOwner, selectedTab])

  // Crear 5 publicaciones mock del usuario actual
  const mockUserPosts: Post[] = useMemo(() => [
    {
      id: 'user-post-1',
      content: 'Bendecido por este hermoso día 🙏❤️',
      mediaUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=800&fit=crop',
      mediaType: 'image',
      mediaUrls: [
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&h=800&fit=crop', // Vertical
      ],
      createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000), // Hace 2 horas
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 200000000, comments: 800 },
      isLiked: false,
    },
    {
      id: 'user-post-2',
      content: 'Compartiendo un momento especial ✨',
      mediaUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      mediaType: 'video',
      mediaUrls: [
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', // Video
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&h=800&fit=crop', // Vertical
      ],
      createdAt: new Date(Date.now() - 5 * 60 * 60 * 1000), // Hace 5 horas
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 78, comments: 23 },
      isLiked: true,
    },
    {
      id: 'user-post-3',
      content: 'Gratitud infinita por todas las bendiciones 🙌',
      mediaUrl: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&h=800&fit=crop',
      mediaType: 'image',
      mediaUrls: [
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=800&fit=crop', // Vertical
      ],
      createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // Hace 1 día
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 92, comments: 18 },
      isLiked: false,
    },
    {
      id: 'user-post-4',
      content: 'Testimonio de fe y esperanza 💫',
      mediaUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=800&fit=crop',
      mediaType: 'image',
      mediaUrls: [
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=800&fit=crop', // Vertical
      ],
      createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // Hace 2 días
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 156, comments: 34 },
      isLiked: true,
    },
    {
      id: 'user-post-5',
      content: 'Reflexión del día: La fe mueve montañas ⛰️',
      mediaUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      mediaType: 'video',
      mediaUrls: [
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', // Video
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=800&fit=crop', // Vertical
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&h=800&fit=crop', // Vertical
      ],
      createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // Hace 3 días
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 203, comments: 45 },
      isLiked: false,
    },
    // Publicaciones anónimas mock
    {
      id: 'user-post-anon-1',
      content: 'Necesito oración por una situación difícil 🙏',
      mediaUrl: null,
      mediaType: null,
      mediaUrls: [],
      createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000),
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 45, comments: 12 },
      isLiked: false,
      isAnonymous: true,
    },
    {
      id: 'user-post-anon-2',
      content: 'Testimonio de sanación que quiero compartir anónimamente ✨',
      mediaUrl: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&h=800&fit=crop',
      mediaType: 'image',
      mediaUrls: [
        'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&h=800&fit=crop', // Vertical
      ],
      createdAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000),
      updatedAt: new Date(),
      authorId: userId,
      author: {
        id: userId,
        name: displayName,
        username: displayUsername,
        email: 'alex@example.com',
        image: null,
        bio: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      _count: { likes: 78, comments: 25 },
      isLiked: true,
      isAnonymous: true,
    },
  ], [userId])

  // Combinar publicaciones mock con las reales del usuario
  const userPosts = useMemo(() => {
    const realUserPosts = posts.filter((post: Post) => {
      return post.authorId === userId
    })
    // Combinar y ordenar por fecha (más recientes primero)
    const allPosts = [...mockUserPosts, ...realUserPosts].sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )
    return allPosts
  }, [posts, userId, mockUserPosts])

  // Filtrar solo publicaciones anónimas del usuario
  const anonymousPosts = useMemo(() => {
    // Filtrar publicaciones anónimas (por ahora verificamos si tiene algún campo que indique que es anónima)
    // TODO: Ajustar la condición según cómo se identifiquen las publicaciones anónimas en tu esquema
    return userPosts.filter((post: Post) => {
      // Por ahora, asumimos que las anónimas tienen un campo isAnonymous o privacy === 'anonymous'
      // Si no existe, puedes usar otra propiedad según tu esquema
      return (post as any).isAnonymous === true || (post as any).privacy === 'anonymous'
    })
  }, [userPosts])

  // Extraer todas las imágenes individuales de las publicaciones del usuario
  const userImages = useMemo(() => {
    const images: Array<{ url: string; postId: string; createdAt: Date }> = []
    
    userPosts.forEach(post => {
      // Si tiene mediaUrl y es imagen
      if (post.mediaUrl && post.mediaType === 'image') {
        images.push({
          url: post.mediaUrl,
          postId: post.id,
          createdAt: post.createdAt
        })
      }
      
      // Si tiene mediaUrls, agregar solo las imágenes
      if (post.mediaUrls && post.mediaUrls.length > 0) {
        post.mediaUrls.forEach(url => {
          // Verificar si es imagen (no video)
          const lowerUrl = url.toLowerCase()
          const isVideo = lowerUrl.includes('.mp4') || 
                         lowerUrl.includes('.webm') || 
                         lowerUrl.includes('video') ||
                         lowerUrl.includes('gtv-videos-bucket')
          
          if (!isVideo) {
            images.push({
              url: url,
              postId: post.id,
              createdAt: post.createdAt
            })
          }
        })
      }
    })
    
    // Ordenar por fecha (más recientes primero)
    return images.sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )
  }, [userPosts])

  // Extraer todos los videos individuales de las publicaciones del usuario
  const userVideos = useMemo(() => {
    const videos: Array<{ url: string; postId: string; createdAt: Date }> = []
    
    // Función para determinar si una URL es un video
    const isVideo = (url: string): boolean => {
      const lowerUrl = url.toLowerCase()
      return lowerUrl.includes('.mp4') || 
             lowerUrl.includes('.webm') || 
             lowerUrl.includes('video') ||
             lowerUrl.includes('gtv-videos-bucket')
    }
    
    userPosts.forEach(post => {
      // Si tiene mediaUrl y es video
      if (post.mediaUrl && (post.mediaType === 'video' || isVideo(post.mediaUrl))) {
        videos.push({
          url: post.mediaUrl,
          postId: post.id,
          createdAt: post.createdAt
        })
      }
      
      // Si tiene mediaUrls, agregar solo los videos
      if (post.mediaUrls && post.mediaUrls.length > 0) {
        post.mediaUrls.forEach(url => {
          if (isVideo(url)) {
            videos.push({
              url: url,
              postId: post.id,
              createdAt: post.createdAt
            })
          }
        })
      }
    })
    
    // Ordenar por fecha (más recientes primero)
    return videos.sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )
  }, [userPosts])

  const handleLike = useCallback(
    (postId: string) => {
      likePost(postId)
    },
    [likePost]
  )

  const handleComment = useCallback((postId: string) => {
    setSelectedPostForComments(postId)
  }, [])

  const handleShare = useCallback((postId: string) => {
    setSelectedPostForShare(postId)
  }, [])

  const handleCommentAdded = useCallback(async () => {
    if (selectedPostForComments) {
      await refreshPost(selectedPostForComments)
    }
  }, [selectedPostForComments, refreshPost])

  const [selectedPostIndex, setSelectedPostIndex] = useState<number | null>(null)
  const [selectedImageIndex, setSelectedImageIndex] = useState<number | null>(null)
  const [selectedVideoIndex, setSelectedVideoIndex] = useState<number | null>(null)

  const handleImageClick = useCallback((postId: string) => {
    // Abrir vista de feed
    const index = userPosts.findIndex(p => p.id === postId)
    if (index !== -1) {
      setSelectedPostIndex(index)
    }
  }, [userPosts])

  const handleClosePostViewer = useCallback(() => {
    setSelectedPostIndex(null)
  }, [])

  const handleCloseImageGallery = useCallback(() => {
    setSelectedImageIndex(null)
  }, [])

  const handleCloseVideoGallery = useCallback(() => {
    setSelectedVideoIndex(null)
  }, [])


  const userImage = null
  const bio = 'Solo sea Feliz 😊❤️💕'
  const statusMessage = 'Feliz Año Nuevo 🎉🎊✨'
  const links = [
    {
      url: 'https://www.youtube.com/channel/UCqDKgOgQtGMaNyLn7dCXNLw',
      label: 'YouTube',
    },
    {
      url: 'https://www.facebook.com/share/16Y3...',
      label: 'Facebook',
    },
  ]

  const stats: UserStats = {
    siguiendo: 253,
    seguidores: 41100,
    meGusta: 142000,
  }

  const formatNumber = (num: number): string => {
    if (num >= 1000000) {
      return `${(num / 1000000).toFixed(1)}M`
    }
    if (num >= 1000) {
      return `${(num / 1000).toFixed(1)}K`
    }
    return num.toString()
  }

  return (
    <div className="min-h-screen bg-white dark:bg-dark-bg pb-24">
      <div className="max-w-md mx-auto">
        {/* Top Bar */}
        <header className="flex items-center justify-between px-4 py-3 bg-white dark:bg-dark-bg border-b border-gray-200 dark:border-dark-border sticky top-0 z-20">
          <button className="w-10 h-10 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-dark-hover rounded-full transition-colors">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
              />
            </svg>
          </button>
          <div className="flex items-center gap-3">
            <button className="w-10 h-10 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-dark-hover rounded-full transition-colors">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                />
              </svg>
            </button>
            <button className="w-10 h-10 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-dark-hover rounded-full transition-colors">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"
                />
              </svg>
            </button>
            <button
              onClick={() => router.push('/settings')}
              className="w-10 h-10 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-dark-hover rounded-full transition-colors"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </button>
          </div>
        </header>

        {/* Profile Content - Horizontal: avatar izquierda, nombre y stats derecha */}
        <div className="px-4 py-6">
          <div className="flex flex-row items-start gap-4">
            {/* Izquierda: foto de perfil */}
            <div className="relative flex-shrink-0">
              <div className="w-20 h-20 rounded-full border-4 border-primary-500 overflow-hidden bg-gray-100 dark:bg-dark-hover flex items-center justify-center">
                {userImage ? (
                  <Avatar
                    src={userImage}
                    alt={displayName}
                    size="xl"
                    className="border-0 w-full h-full"
                  />
                ) : (
                  <div className="w-full h-full bg-primary-500 flex items-center justify-center text-white text-3xl font-bold">
                    {displayName.charAt(0).toUpperCase()}
                  </div>
                )}
              </div>
              <button className="absolute bottom-0 right-0 w-6 h-6 bg-primary-500 rounded-full flex items-center justify-center text-white shadow-lg border-2 border-white dark:border-dark-bg hover:bg-primary-600 transition-colors">
                <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
              </button>
            </div>

            {/* Derecha: nombre (con editar en esquina), usuario, estadísticas */}
            <div className="flex flex-col min-w-0 flex-1">
              <div className="flex items-start justify-between gap-2">
                <h1 className="text-xl font-black text-gray-900 dark:text-white tracking-tight leading-tight">{displayName}</h1>
                <button
                  className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-md border border-gray-300 dark:border-gray-500 bg-transparent hover:bg-gray-100 dark:hover:bg-dark-hover text-gray-600 dark:text-gray-300 transition-colors"
                  aria-label="Editar perfil"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
              </div>
              <p className="text-gray-500 dark:text-gray-400 text-sm font-normal mt-0.5">{displayUsername}</p>
              <div className="flex gap-4 mt-3">
                <div>
                  <p className="text-gray-900 dark:text-white font-bold text-base leading-none">{stats.siguiendo}</p>
                  <p className="text-gray-500 dark:text-gray-400 text-xs font-normal mt-0.5">Siguiendo</p>
                </div>
                <div>
                  <p className="text-gray-900 dark:text-white font-bold text-base leading-none">{formatNumber(stats.seguidores)}</p>
                  <p className="text-gray-500 dark:text-gray-400 text-xs font-normal mt-0.5">Seguidores</p>
                </div>
                <div>
                  <p className="text-gray-900 dark:text-white font-bold text-base leading-none">{formatNumber(stats.meGusta)}</p>
                  <p className="text-gray-500 dark:text-gray-400 text-xs font-normal mt-0.5">Me gusta</p>
                </div>
              </div>
            </div>
          </div>

          {/* Links */}
          <div className="space-y-1 mb-6 mt-4">
            {links.map((link, index) => (
              <a
                key={index}
                href={link.url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-gray-700 dark:text-white hover:text-gray-900 dark:hover:text-gray-200 text-sm break-all font-normal transition-colors"
              >
                {index === 0 ? (
                  <>
                    <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                      />
                    </svg>
                    <span>{link.url}</span>
                  </>
                ) : (
                  <>
                    <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                      />
                    </svg>
                    <span>{link.url}</span>
                  </>
                )}
              </a>
            ))}
          </div>

          {/* Feelings Selector */}
          <FeelingsSelector selectedFeeling={selectedFeeling} onFeelingChange={setSelectedFeeling} />

          {/* Navigation Tabs */}
          <div className="flex items-center justify-center gap-4 mb-4 border-b border-gray-200 dark:border-dark-border pb-1 mt-0">
            <button
              onClick={() => setSelectedTab('publicaciones')}
              className={`text-base font-bold transition-colors pb-2 ${
                selectedTab === 'publicaciones'
                  ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400'
                  : 'text-gray-900 dark:text-white hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              Publicaciones
            </button>
            {isProfileOwner && (
              <button
                onClick={() => setSelectedTab('anonimos')}
                className={`text-base font-bold transition-colors pb-2 ${
                  selectedTab === 'anonimos'
                    ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400'
                    : 'text-gray-900 dark:text-white hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                Anónimos
              </button>
            )}
            <button
              onClick={() => setSelectedTab('listas')}
              className={`text-base font-bold transition-colors pb-2 ${
                selectedTab === 'listas'
                  ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400'
                  : 'text-gray-900 dark:text-white hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              Listas
            </button>
          </div>

          {/* Anónimos Grid */}
          {selectedTab === 'anonimos' && isProfileOwner && (
            <div className="grid grid-cols-3 gap-px">
              {anonymousPosts.length > 0 ? (
                anonymousPosts
                  .filter((post) => {
                    // Solo mostrar publicaciones que tengan al menos un medio
                    return post.mediaUrl || (post.mediaUrls && post.mediaUrls.length > 0)
                  })
                  .map((post) => {
                  // Función para determinar si una URL es un video
                  const isVideo = (url: string): boolean => {
                    const lowerUrl = url.toLowerCase()
                    return lowerUrl.includes('.mp4') || 
                           lowerUrl.includes('.webm') || 
                           lowerUrl.includes('video') ||
                           lowerUrl.includes('gtv-videos-bucket')
                  }
                  
                  // Recopilar todos los medios
                  const allMedia: Array<{ url: string; type: 'image' | 'video' }> = []
                  
                  if (post.mediaUrl) {
                    allMedia.push({
                      url: post.mediaUrl,
                      type: post.mediaType === 'video' || isVideo(post.mediaUrl) ? 'video' : 'image'
                    })
                  }
                  
                  if (post.mediaUrls && post.mediaUrls.length > 0) {
                    post.mediaUrls.forEach(url => {
                      allMedia.push({
                        url,
                        type: isVideo(url) ? 'video' : 'image'
                      })
                    })
                  }
                  
                  const hasMultipleMedia = allMedia.length > 1
                  const displayMedia = allMedia[0]
                  
                  // Formatear números
                  const formatCount = (count: number): string => {
                    if (count >= 1000000) {
                      const millions = count / 1000000
                      return millions % 1 === 0 ? `${millions} mill.` : `${millions.toFixed(1)} mill.`
                    }
                    if (count >= 1000) {
                      const thousands = count / 1000
                      return thousands % 1 === 0 ? `${thousands} mil` : `${thousands.toFixed(1)} mil`
                    }
                    return count.toString()
                  }
                  
                  const likesCount = formatCount(post._count?.likes || 0)
                  const commentsCount = formatCount(post._count?.comments || 0)
                  
                  return (
                    <div
                      key={post.id}
                      onClick={() => handleImageClick(post.id)}
                      className="bg-white dark:bg-dark-card overflow-hidden cursor-pointer shadow-md hover:shadow-lg transition-shadow relative"
                    >
                      {/* Media */}
                      <div className="aspect-square bg-gray-100 dark:bg-dark-hover relative">
                        {displayMedia && displayMedia.type === 'image' ? (
                          <Image
                            src={displayMedia.url}
                            alt="Post"
                            fill
                            className="object-cover"
                            sizes="(max-width: 768px) 33vw, 150px"
                          />
                        ) : displayMedia && displayMedia.type === 'video' ? (
                          <>
                            <video
                              src={displayMedia.url}
                              className="w-full h-full object-cover"
                              muted
                            />
                            <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-8 h-8 bg-black/50 rounded-full flex items-center justify-center">
                              <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M8 5v14l11-7z" />
                              </svg>
                            </div>
                          </>
                        ) : null}
                        
                        {/* Indicador de cantidad si hay múltiples medios */}
                        {hasMultipleMedia && (
                          <div className="absolute top-2 right-2 bg-black/70 rounded px-1 py-0.5 min-w-[18px] min-h-[18px] flex items-center justify-center leading-none">
                            <span className="text-white text-[9px] font-semibold leading-none inline-block pt-px">
                              {allMedia.length}
                            </span>
                          </div>
                        )}
                        
                        {/* Métricas en la parte inferior */}
                        <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 via-black/50 to-transparent p-2">
                          <div className="flex items-center gap-3 text-white">
                            <div className="flex items-center gap-1">
                              <svg className="w-4 h-4" fill={post.isLiked ? '#ef4444' : 'none'} stroke={post.isLiked ? 'none' : 'currentColor'} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={post.isLiked ? 0 : 2} d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
                              </svg>
                              <span className="text-xs font-semibold">{likesCount}</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.488.348.332.697.638 1.05.94l-1.35 3.75 3.75-1.35c.302.353.608.702.94 1.05C7.977 19.141 9.896 20 12 20.25z" />
                              </svg>
                              <span className="text-xs font-semibold">{commentsCount}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  )
                })
              ) : (
                <div className="col-span-3 text-center py-8 text-gray-500 dark:text-gray-400 text-sm">
                  No hay publicaciones anónimas todavía
                </div>
              )}
            </div>
          )}

          {/* Listas */}
          {selectedTab === 'listas' && (
            <div className="divide-y divide-gray-200 dark:divide-dark-border">
              {userPosts.slice(0, 10).map((post) => {
                const likesCount = post._count?.likes ?? 0
                const commentsCount = post._count?.comments ?? 0
                const dateStr = new Date(post.createdAt).toLocaleDateString('es', { day: 'numeric', month: 'short' })
                return (
                  <div
                    key={post.id}
                    className="border-0 rounded-none px-4 py-2.5 bg-transparent"
                  >
                    {/* Fila: título a la izquierda, fecha a la derecha */}
                    <div className="flex justify-between items-start gap-3">
                      <p className="text-sm text-gray-900 dark:text-white leading-snug flex-1 min-w-0 whitespace-pre-wrap break-words">
                        {post.content}
                      </p>
                      <span className="text-xs text-gray-500 dark:text-gray-400 tabular-nums flex-shrink-0">
                        {dateStr}
                      </span>
                    </div>
                    {/* Fila: likes (rojo), comentarios (blanco) */}
                    <div className="mt-1.5 flex items-center gap-4">
                      <span className="flex items-center gap-1 text-xs font-medium text-red-500 dark:text-red-400">
                        <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
                        </svg>
                        {likesCount >= 1000 ? `${(likesCount / 1000).toFixed(1)}K` : likesCount.toLocaleString()}
                      </span>
                      <span className="flex items-center gap-1 text-xs font-medium text-gray-700 dark:text-white">
                        <svg className="w-3.5 h-3.5 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.488.348.332.697.638 1.05.94l-1.35 3.75 3.75-1.35c.302.353.608.702.94 1.05C7.977 19.141 9.896 20 12 20.25z" />
                        </svg>
                        {commentsCount >= 1000 ? `${(commentsCount / 1000).toFixed(1)}K` : commentsCount.toLocaleString()}
                      </span>
                    </div>
                  </div>
                )
              })}
              {userPosts.length === 0 && (
                <div className="py-8 text-center text-gray-500 dark:text-gray-400 text-sm">
                  Tus listas aparecerán aquí
                </div>
              )}
            </div>
          )}

          {/* Publicaciones Grid */}
          {selectedTab === 'publicaciones' && (
            <div className="grid grid-cols-3 gap-px">
              {userPosts.length > 0 ? (
                userPosts
                  .filter((post) => {
                    // Solo mostrar publicaciones que tengan al menos un medio
                    return post.mediaUrl || (post.mediaUrls && post.mediaUrls.length > 0)
                  })
                  .map((post) => {
                  // Función para determinar si una URL es un video
                  const isVideo = (url: string): boolean => {
                    const lowerUrl = url.toLowerCase()
                    return lowerUrl.includes('.mp4') || 
                           lowerUrl.includes('.webm') || 
                           lowerUrl.includes('video') ||
                           lowerUrl.includes('gtv-videos-bucket')
                  }
                  
                  // Recopilar todos los medios
                  const allMedia: Array<{ url: string; type: 'image' | 'video' }> = []
                  
                  if (post.mediaUrl) {
                    allMedia.push({
                      url: post.mediaUrl,
                      type: post.mediaType === 'video' || isVideo(post.mediaUrl) ? 'video' : 'image'
                    })
                  }
                  
                  if (post.mediaUrls && post.mediaUrls.length > 0) {
                    post.mediaUrls.forEach(url => {
                      allMedia.push({
                        url,
                        type: isVideo(url) ? 'video' : 'image'
                      })
                    })
                  }
                  
                  const hasMultipleMedia = allMedia.length > 1
                  const displayMedia = allMedia[0]
                  
                  // Formatear números
                  const formatCount = (count: number): string => {
                    if (count >= 1000000) {
                      const millions = count / 1000000
                      return millions % 1 === 0 ? `${millions} mill.` : `${millions.toFixed(1)} mill.`
                    }
                    if (count >= 1000) {
                      const thousands = count / 1000
                      return thousands % 1 === 0 ? `${thousands} mil` : `${thousands.toFixed(1)} mil`
                    }
                    return count.toString()
                  }
                  
                  const likesCount = formatCount(post._count?.likes || 0)
                  const commentsCount = formatCount(post._count?.comments || 0)
                  
                  return (
                    <div
                      key={post.id}
                      onClick={() => handleImageClick(post.id)}
                      className="bg-white dark:bg-dark-card overflow-hidden cursor-pointer shadow-md hover:shadow-lg transition-shadow relative"
                    >
                      {/* Media */}
                      <div className="aspect-square bg-gray-100 dark:bg-dark-hover relative">
                        {displayMedia && displayMedia.type === 'image' ? (
                          <Image
                            src={displayMedia.url}
                            alt="Post"
                            fill
                            className="object-cover"
                            sizes="(max-width: 768px) 33vw, 150px"
                          />
                        ) : displayMedia && displayMedia.type === 'video' ? (
                          <>
                            <video
                              src={displayMedia.url}
                              className="w-full h-full object-cover"
                              muted
                            />
                            <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-8 h-8 bg-black/50 rounded-full flex items-center justify-center">
                              <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M8 5v14l11-7z" />
                              </svg>
                            </div>
                          </>
                        ) : null}
                        
                        {/* Indicador de cantidad si hay múltiples medios */}
                        {hasMultipleMedia && (
                          <div className="absolute top-2 right-2 bg-black/70 rounded px-1 py-0.5 min-w-[18px] min-h-[18px] flex items-center justify-center leading-none">
                            <span className="text-white text-[9px] font-semibold leading-none inline-block pt-px">
                              {allMedia.length}
                            </span>
                          </div>
                        )}
                        
                        {/* Métricas en la parte inferior */}
                        <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 via-black/50 to-transparent p-2">
                          <div className="flex items-center gap-3 text-white">
                            <div className="flex items-center gap-1">
                              <svg className="w-4 h-4" fill={post.isLiked ? '#ef4444' : 'none'} stroke={post.isLiked ? 'none' : 'currentColor'} viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={post.isLiked ? 0 : 2} d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
                              </svg>
                              <span className="text-xs font-semibold">{likesCount}</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.488.348.332.697.638 1.05.94l-1.35 3.75 3.75-1.35c.302.353.608.702.94 1.05C7.977 19.141 9.896 20 12 20.25z" />
                              </svg>
                              <span className="text-xs font-semibold">{commentsCount}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  )
                })
              ) : (
                <div className="col-span-3 text-center py-8 text-gray-500 dark:text-gray-400 text-sm">
                  No hay publicaciones todavía
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Bottom Navigation */}
      <BottomNavigation />

      {/* Image Gallery Modal - Horizontal Scroll (Swipe) */}
      {selectedImageIndex !== null && userImages.length > 0 && (
        <div className="fixed inset-0 bg-black z-50 overflow-hidden">
          {/* Close Button */}
          <button
            onClick={handleCloseImageGallery}
            className="absolute top-4 left-4 z-50 w-10 h-10 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/70 transition-all"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Image Counter */}
          <div className="absolute top-4 right-4 z-50 bg-black/50 rounded-full px-3 py-1">
            <span className="text-white text-sm font-medium">
              {selectedImageIndex + 1}/{userImages.length}
            </span>
          </div>

          {/* Images Container - Horizontal Scroll (Swipe) */}
          <div
            className="w-full h-full flex overflow-x-scroll snap-x snap-mandatory scrollbar-hide"
            style={{
              scrollSnapType: 'x mandatory',
            }}
            onScroll={(e) => {
              const container = e.currentTarget
              const scrollLeft = container.scrollLeft
              const imageWidth = container.clientWidth
              const newIndex = Math.round(scrollLeft / imageWidth)
              if (newIndex !== selectedImageIndex && newIndex >= 0 && newIndex < userImages.length) {
                setSelectedImageIndex(newIndex)
              }
            }}
            ref={(el) => {
              if (el && selectedImageIndex !== null) {
                const targetScroll = selectedImageIndex * el.clientWidth
                if (Math.abs(el.scrollLeft - targetScroll) > 1) {
                  el.scrollTo({
                    left: targetScroll,
                    behavior: 'instant'
                  })
                }
              }
            }}
          >
            {userImages.map((image, index) => (
              <div
                key={`${image.postId}-${index}`}
                className="flex-shrink-0 w-full h-full flex items-center justify-center snap-center relative"
              >
                <Image
                  src={image.url}
                  alt={`Imagen ${index + 1}`}
                  fill
                  className="object-contain"
                  priority={index === selectedImageIndex}
                />
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Video Gallery Modal - Horizontal Scroll (Swipe) */}
      {selectedVideoIndex !== null && userVideos.length > 0 && (
        <div className="fixed inset-0 bg-black z-50 overflow-hidden">
          {/* Close Button */}
          <button
            onClick={handleCloseVideoGallery}
            className="absolute top-4 left-4 z-50 w-10 h-10 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/70 transition-all"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Video Counter */}
          <div className="absolute top-4 right-4 z-50 bg-black/50 rounded-full px-3 py-1">
            <span className="text-white text-sm font-medium">
              {selectedVideoIndex + 1}/{userVideos.length}
            </span>
          </div>

          {/* Videos Container - Horizontal Scroll (Swipe) */}
          <div
            className="w-full h-full flex overflow-x-scroll snap-x snap-mandatory scrollbar-hide"
            style={{
              scrollSnapType: 'x mandatory',
            }}
            onScroll={(e) => {
              const container = e.currentTarget
              const scrollLeft = container.scrollLeft
              const videoWidth = container.clientWidth
              const newIndex = Math.round(scrollLeft / videoWidth)
              if (newIndex !== selectedVideoIndex && newIndex >= 0 && newIndex < userVideos.length) {
                setSelectedVideoIndex(newIndex)
              }
            }}
            ref={(el) => {
              if (el && selectedVideoIndex !== null) {
                const targetScroll = selectedVideoIndex * el.clientWidth
                if (Math.abs(el.scrollLeft - targetScroll) > 1) {
                  el.scrollTo({
                    left: targetScroll,
                    behavior: 'instant'
                  })
                }
              }
            }}
          >
            {userVideos.map((video, index) => (
              <div
                key={`${video.postId}-${index}`}
                className="flex-shrink-0 w-full h-full flex items-center justify-center snap-center relative"
              >
                <video
                  src={video.url}
                  className="max-w-full max-h-full object-contain"
                  controls
                  autoPlay={index === selectedVideoIndex}
                  muted
                />
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Post Viewer Modal - Similar to Feed */}
      {selectedPostIndex !== null && userPosts.length > 0 && (
        <div className="fixed inset-0 bg-gray-200 dark:bg-dark-bg z-50 overflow-y-auto">
          {/* Close Button */}
          <button
            onClick={handleClosePostViewer}
            className="absolute top-4 left-4 z-50 w-10 h-10 bg-white/90 dark:bg-dark-card/90 rounded-full flex items-center justify-center text-gray-700 dark:text-white hover:bg-white dark:hover:bg-dark-card shadow-lg transition-all"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Posts Container - Full Width */}
          <div className="w-full pt-16 pb-8">
            {userPosts.map((post, index) => (
              <div
                key={post.id}
                className="mb-4"
                ref={(el) => {
                  if (index === selectedPostIndex && el) {
                    setTimeout(() => {
                      el.scrollIntoView({ behavior: 'smooth', block: 'start' })
                    }, 100)
                  }
                }}
              >
                <PostCard
                  id={post.id}
                  content={post.content}
                  author={post.author}
                  mediaUrl={post.mediaUrl}
                  mediaType={post.mediaType}
                  mediaUrls={post.mediaUrls}
                  createdAt={post.createdAt}
                  likesCount={post._count?.likes || 0}
                  commentsCount={post._count?.comments || 0}
                  isLiked={post.isLiked || false}
                  postType={(post as any).postType}
                  intercessionsCount={(post as any).intercessionsCount}
                  hasInterceded={(post as any).hasInterceded}
                  isAnswered={(post as any).isAnswered}
                  onLike={handleLike}
                  onComment={handleComment}
                  onShare={handleShare}
                  onMenuClick={() => {}}
                  onVideoClick={(postId) => {
                    const idx = userPosts.findIndex(p => p.id === postId)
                    if (idx !== -1) setSelectedPostIndex(idx)
                  }}
                  onImageClick={(postId) => {
                    const idx = userPosts.findIndex(p => p.id === postId)
                    if (idx !== -1) setSelectedPostIndex(idx)
                  }}
                  onIntercede={() => {}}
                />
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Comments Modal */}
      {selectedPostForComments && (
        <CommentsModal
          postId={selectedPostForComments}
          isOpen={!!selectedPostForComments}
          onClose={() => setSelectedPostForComments(null)}
          onCommentAdded={handleCommentAdded}
        />
      )}

      {/* Share Modal */}
      {selectedPostForShare && (
        <ShareModal
          postId={selectedPostForShare}
          isOpen={!!selectedPostForShare}
          onClose={() => setSelectedPostForShare(null)}
        />
      )}
    </div>
  )
}
