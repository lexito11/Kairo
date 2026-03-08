import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { postSelect } from '../utils'

// URLs de videos e imágenes en formato Facebook estándar
// Imágenes verticales: 1080x1350 (4:5) - Formato estándar de Facebook
// Videos verticales: 1080x1920 (9:16) - Formato tipo celular
const verticalMedia = [
  {
    // Primera publicación - Video + imagen formato Facebook
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=1080&h=1350&fit=crop',
  },
  {
    // Segunda publicación - Video + imagen formato Facebook
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1080&h=1350&fit=crop',
  },
  {
    // Cuarta publicación - Video + imagen formato Facebook
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1080&h=1350&fit=crop',
  },
]

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'No autorizado' },
        { status: 401 }
      )
    }

    // Obtener todas las publicaciones ordenadas por fecha de creación (más recientes primero)
    const allPosts = await prisma.post.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
      },
    })

    if (allPosts.length < 4) {
      return NextResponse.json(
        { error: 'No hay suficientes publicaciones en el feed' },
        { status: 400 }
      )
    }

    // Índices: primera (0), segunda (1), cuarta (3)
    const indicesToUpdate = [0, 1, 3]
    const updatedPosts = []

    for (let i = 0; i < indicesToUpdate.length; i++) {
      const postIndex = indicesToUpdate[i]
      if (postIndex >= allPosts.length) continue

      const postId = allPosts[postIndex].id
      const mediaData = verticalMedia[i]

      // Almacenar video e imagen como JSON array
      const mediaUrls = JSON.stringify([mediaData.videoUrl, mediaData.imageUrl])

      // Actualizar el post
      const updatedPost = await prisma.post.update({
        where: { id: postId },
        data: {
          mediaUrl: mediaUrls,
          mediaType: 'video',
        },
        select: postSelect,
      })

      // Transformar para incluir mediaUrls
      let parsedMediaUrls: string[] | null = null
      try {
        parsedMediaUrls = JSON.parse(updatedPost.mediaUrl || '[]')
      } catch {
        parsedMediaUrls = updatedPost.mediaUrl ? [updatedPost.mediaUrl] : null
      }

      updatedPosts.push({
        ...updatedPost,
        mediaUrls: parsedMediaUrls,
      })
    }

    return NextResponse.json({
      message: 'Publicaciones actualizadas a formato vertical tipo celular',
      updatedPosts,
      updatedIndices: indicesToUpdate.map(i => i + 1), // Mostrar como 1ra, 2da, 4ta
    })
  } catch (error) {
    console.error('Error updating posts:', error)
    return NextResponse.json(
      { error: 'Error al actualizar publicaciones' },
      { status: 500 }
    )
  }
}

