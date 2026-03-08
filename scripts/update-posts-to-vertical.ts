import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// URLs de videos e imágenes verticales tipo celular
const verticalMedia = [
  {
    // Primera publicación - Video vertical + imagen vertical
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=800&h=1200&fit=crop',
  },
  {
    // Segunda publicación - Video vertical + imagen vertical
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=1200&fit=crop',
  },
  {
    // Cuarta publicación - Video vertical + imagen vertical
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=1200&fit=crop',
  },
]

async function updatePostsToVertical() {
  try {
    // Obtener todas las publicaciones ordenadas por fecha de creación (más recientes primero)
    const allPosts = await prisma.post.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
      },
    })

    if (allPosts.length < 4) {
      console.log('❌ No hay suficientes publicaciones en el feed')
      return
    }

    // Índices: primera (0), segunda (1), cuarta (3)
    const indicesToUpdate = [0, 1, 3]

    for (let i = 0; i < indicesToUpdate.length; i++) {
      const postIndex = indicesToUpdate[i]
      if (postIndex >= allPosts.length) continue

      const postId = allPosts[postIndex].id
      const mediaData = verticalMedia[i]

      // Almacenar video e imagen como JSON array
      const mediaUrls = JSON.stringify([mediaData.videoUrl, mediaData.imageUrl])

      // Actualizar el post
      await prisma.post.update({
        where: { id: postId },
        data: {
          mediaUrl: mediaUrls,
          mediaType: 'video',
        },
      })

      console.log(`✅ Publicación ${postIndex + 1} actualizada a formato vertical`)
    }

    console.log('✅ Todas las publicaciones han sido actualizadas')
  } catch (error) {
    console.error('❌ Error:', error)
  } finally {
    await prisma.$disconnect()
  }
}

updatePostsToVertical()


