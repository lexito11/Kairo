import { useState, useEffect, useCallback } from 'react'
import { Post } from '@/types'
import { PaginationInfo } from './types'

// Función para calcular el score de popularidad
function calculatePopularityScore(post: Post): number {
  const likes = post._count?.likes || 0
  const comments = post._count?.comments || 0
  const now = Date.now()
  const createdAt = new Date(post.createdAt).getTime()
  const hoursSinceCreation = (now - createdAt) / (1000 * 60 * 60)
  
  // Score base: likes y comentarios
  const engagementScore = likes * 2 + comments * 3
  
  // Factor de tiempo: posts más recientes tienen un boost
  // Decae exponencialmente con el tiempo
  const timeFactor = Math.max(0.1, 1 / (1 + hoursSinceCreation / 24))
  
  // Score final combinado
  return engagementScore * (1 + timeFactor)
}

// Función para ordenar posts aleatoriamente basado en popularidad
function sortPostsByPopularityRandom(posts: Post[]): Post[] {
  // Calcular scores de popularidad
  const postsWithScores = posts.map(post => ({
    post,
    popularityScore: calculatePopularityScore(post),
  }))
  
  // Generar un factor de aleatoriedad único para esta sesión
  // Usamos una semilla basada en la fecha actual (cambia cada minuto para más variación)
  // Esto hace que el orden cambie frecuentemente pero mantenga cierta consistencia
  const seed = Math.floor(Date.now() / (1000 * 60))
  const random = (seed: number) => {
    const x = Math.sin(seed) * 10000
    return x - Math.floor(x)
  }
  
  // Ordenar combinando popularidad con aleatoriedad
  postsWithScores.sort((a, b) => {
    // Aplicar factor de aleatoriedad (0.3 = 30% de aleatoriedad)
    const randomFactorA = random(seed + parseInt(a.post.id)) * 0.3
    const randomFactorB = random(seed + parseInt(b.post.id)) * 0.3
    
    // Score final = popularidad * (1 - aleatoriedad) + aleatoriedad
    const scoreA = a.popularityScore * (1 - randomFactorA) + randomFactorA * 1000
    const scoreB = b.popularityScore * (1 - randomFactorB) + randomFactorB * 1000
    
    return scoreB - scoreA // Orden descendente
  })
  
  return postsWithScores.map(item => item.post)
}

export function usePosts() {
  const [posts, setPosts] = useState<Post[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [pagination, setPagination] = useState<PaginationInfo | null>(null)
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(true)

  const fetchPosts = useCallback(async (pageNum: number = 1, append: boolean = false) => {
    try {
      setLoading(true)
      
      // Intentar obtener de la API
      try {
        const response = await fetch(`/api/posts?page=${pageNum}&limit=10`)
        if (response.ok) {
          const data = await response.json()
          if (append) {
            setPosts((prev) => [...prev, ...data.posts])
          } else {
            setPosts(data.posts)
          }
          setPagination(data.pagination)
          setHasMore(data.pagination.page < data.pagination.totalPages)
          setLoading(false)
          return
        }
      } catch (apiError) {
        // Si falla la API, usar datos de ejemplo
        console.log('API no disponible, usando datos de ejemplo')
      }
      
      // Usar datos de ejemplo si la API no está disponible
      const { mockPosts } = await import('./mockData')
      
      // Aplicar ordenamiento aleatorio basado en popularidad
      const sortedMockPosts = sortPostsByPopularityRandom([...mockPosts])
      
      const startIndex = (pageNum - 1) * 10
      const endIndex = startIndex + 10
      const pagePosts = sortedMockPosts.slice(startIndex, endIndex)
      
      if (append) {
        setPosts((prev) => [...prev, ...pagePosts])
      } else {
        setPosts(pagePosts)
      }
      
      setPagination({
        page: pageNum,
        limit: 10,
        total: sortedMockPosts.length,
        totalPages: Math.ceil(sortedMockPosts.length / 10),
      })
      setHasMore(endIndex < sortedMockPosts.length)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error desconocido')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchPosts(1, false)
  }, [fetchPosts])

  const loadMore = useCallback(() => {
    if (!loading && hasMore) {
      const nextPage = page + 1
      setPage(nextPage)
      fetchPosts(nextPage, true)
    }
  }, [loading, hasMore, page, fetchPosts])

  const createPost = async (content: string, file?: File) => {
    try {
      const formData = new FormData()
      formData.append('content', content)
      if (file) {
        formData.append('file', file)
      }

      const response = await fetch('/api/posts', {
        method: 'POST',
        body: formData,
      })

      if (!response.ok) throw new Error('Error al crear post')
      
      const newPost = await response.json()
      setPosts((prev) => [newPost, ...prev])
      return newPost
    } catch (err) {
      throw err
    }
  }

  const likePost = async (postId: string) => {
    try {
      const response = await fetch(`/api/posts/${postId}/like`, {
        method: 'POST',
      })

      if (!response.ok) throw new Error('Error al dar like')
      
      const updatedPost = await response.json()
      
      // Actualizar el post con la información correcta incluyendo isLiked
      setPosts((prev) =>
        prev.map((post) => {
          if (post.id === postId) {
            return {
              ...updatedPost,
              isLiked: updatedPost.isLiked ?? false,
              _count: {
                likes: updatedPost._count?.likes ?? 0,
                comments: updatedPost._count?.comments ?? 0,
              },
            }
          }
          return post
        })
      )
    } catch (err) {
      console.error('Error al dar like:', err)
      // Revertir cambio optimista en caso de error
      setPosts((prev) =>
        prev.map((post) => {
          if (post.id === postId) {
            return {
              ...post,
              isLiked: !post.isLiked,
              _count: {
                likes: (post._count?.likes ?? 0) + (post.isLiked ? -1 : 1),
                comments: post._count?.comments ?? 0,
              },
            }
          }
          return post
        })
      )
    }
  }

  const refreshPost = async (postId: string) => {
    try {
      // Obtener el post actualizado desde la API
      const response = await fetch(`/api/posts/${postId}`)
      if (response.ok) {
        const updatedPost = await response.json()
        setPosts((prev) =>
          prev.map((post) => (post.id === postId ? updatedPost : post))
        )
      }
    } catch (err) {
      console.error('Error refreshing post:', err)
    }
  }

  return {
    posts,
    loading,
    error,
    pagination,
    hasMore,
    fetchPosts,
    loadMore,
    createPost,
    likePost,
    refreshPost,
  }
}

