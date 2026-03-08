'use client'

import { useEffect, useState } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { usePosts } from '@/hooks/usePosts'
import { PostCard } from '@/components/molecules/PostCard'
import { PostCardSkeleton } from '@/components/molecules/PostCard'
import { Button } from '@/components/atoms/Button'

export default function Home() {
  const { data: session } = useSession()
  const router = useRouter()
  const { posts, loading } = usePosts()
  
  // Obtener los 3 testimonios más destacados (por likes + comentarios)
  const featuredPosts = posts
    .slice()
    .sort((a, b) => {
      const scoreA = (a._count?.likes || 0) + (a._count?.comments || 0)
      const scoreB = (b._count?.likes || 0) + (b._count?.comments || 0)
      return scoreB - scoreA
    })
    .slice(0, 3)

  // Handlers para interacciones
  const handleLike = () => {
    // Funciona sin sesión
  }

  const handleComment = () => {
    // Funciona sin sesión
  }

  const handleShare = () => {
    // Funciona sin sesión
  }

  const handleMenuClick = () => {}

  const handleVideoClick = () => {}

  const handleImageClick = () => {}

  return (
    <div className="min-h-screen bg-dark-bg">
      <div className="max-w-md mx-auto">
        {/* Header - Mismo diseño que el feed */}
        <header className="flex items-center justify-between px-4 py-3 bg-dark-bg/95 backdrop-blur-md sticky top-0 z-20 border-b border-dark-border">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 bg-gradient-to-tr from-primary-500 to-purple-600 rounded-xl flex items-center justify-center text-white text-sm shadow-lg shadow-primary-500/30">
              <span>🙏</span>
            </div>
            <span className="font-bold text-lg bg-gradient-to-r from-primary-500 to-purple-500 bg-clip-text text-transparent">
              TestimonioApp
            </span>
          </div>
          <div className="flex items-center gap-2">
            <Link href="/feed">
              <Button size="sm" variant="outline" className="bg-dark-hover border-dark-border text-white hover:bg-dark-border">
                Ir al Feed
              </Button>
            </Link>
          </div>
        </header>

        {/* Hero Section */}
        <div className="px-4 py-8 text-center border-b border-dark-border">
          <h1 className="text-3xl font-bold mb-3 bg-gradient-to-r from-primary-400 to-purple-400 bg-clip-text text-transparent">
            Historias de Transformación
          </h1>
          <p className="text-dark-text-secondary mb-6 text-lg">
            Descubre testimonios que inspiran. Conecta con una comunidad que comparte esperanza y fe.
          </p>
          <div className="flex gap-3 justify-center">
            <Link href="/feed">
              <Button size="lg" className="bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700">
                Explorar Testimonios
              </Button>
            </Link>
          </div>
        </div>

        {/* Featured Testimonios */}
        <div className="px-4 py-6">
          <h2 className="text-xl font-bold mb-4 text-white">Testimonios Destacados</h2>
          
          {loading && posts.length === 0 ? (
            <>
              <PostCardSkeleton />
              <PostCardSkeleton />
            </>
          ) : featuredPosts.length > 0 ? (
            <>
              {featuredPosts.map((post) => (
                <PostCard
                  key={post.id}
                  id={post.id}
                  content={post.content}
                  author={post.author}
                  mediaUrl={post.mediaUrl}
                  mediaType={post.mediaType}
                  mediaUrls={post.mediaUrls}
                  createdAt={post.createdAt}
                  likesCount={post._count?.likes || 0}
                  commentsCount={post._count?.comments || 0}
                  isLiked={false}
                  postType={(post as any).postType}
                  intercessionsCount={(post as any).intercessionsCount}
                  hasInterceded={(post as any).hasInterceded}
                  isAnswered={(post as any).isAnswered}
                  onLike={handleLike}
                  onComment={handleComment}
                  onShare={handleShare}
                  onMenuClick={handleMenuClick}
                  onVideoClick={handleVideoClick}
                  onImageClick={handleImageClick}
                  onIntercede={(postId) => {
                    // Por ahora solo visual, sin backend
                    console.log('Intercediendo por petición:', postId)
                  }}
                />
              ))}
              
              <div className="mt-6 p-4 bg-dark-card rounded-xl border border-dark-border text-center">
                <Link href="/feed">
                  <Button className="w-full bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700">
                    Ver Más Testimonios
                  </Button>
                </Link>
              </div>
            </>
          ) : (
            <div className="text-center py-12 text-dark-text-secondary">
              <p className="mb-4">Aún no hay testimonios destacados</p>
              <Link href="/feed">
                <Button className="bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700">
                  Ver Feed Completo
                </Button>
              </Link>
            </div>
          )}
        </div>

        {/* Call to Action Footer */}
        <div className="px-4 py-8 border-t border-dark-border">
          <div className="text-center">
            <h3 className="text-xl font-bold mb-2 text-white">Explora nuestra comunidad</h3>
            <p className="text-dark-text-secondary mb-6">
              Descubre historias de transformación y conecta con otros en su camino de fe
            </p>
            <Link href="/feed">
              <Button size="lg" className="bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700">
                Ver Todos los Testimonios
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}
