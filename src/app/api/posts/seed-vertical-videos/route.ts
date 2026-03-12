import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { postSelect } from '../utils'

// Posts con video e imagen formato Facebook estándar
// Imágenes verticales: 1080x1350 (4:5) - Formato estándar de Facebook para feed
// Videos verticales: 1080x1920 (9:16) - Formato tipo celular
const postsWithMedia = [
  {
    content: '¡Bendiciones hermanos! Comparto con ustedes este momento especial de adoración. Que la paz del Señor esté con todos ustedes. 🙏✨',
    // Video formato Facebook (vertical tipo celular)
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    // Imagen formato Facebook (1080x1350 - 4:5)
    imageUrl: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=1080&h=1350&fit=crop',
  },
  {
    content: 'Hermanos y hermanas, quiero compartir con ustedes una reflexión sobre la gratitud. Cada día es un regalo de Dios y debemos estar agradecidos por todas sus bendiciones. 💝',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1080&h=1350&fit=crop',
  },
  {
    content: 'Testimonio de fe: Hoy quiero compartir cómo Dios ha obrado en mi vida. Su amor y misericordia son infinitos. ¡Alabado sea el Señor! 🌟',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1080&h=1350&fit=crop',
  },
  {
    content: 'Noche de alabanza en la iglesia. Dios se movió de una forma poderosa en cada canción. 🎵🔥',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=1080&h=1350&fit=crop',
  },
  {
    content: 'Jóvenes adorando juntos en retiro espiritual. Que cada generación conozca a Jesús. 🙌',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    imageUrl: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1080&h=1350&fit=crop',
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

    // Obtener el usuario actual
    const user = await prisma.user.findUnique({
      where: { id: session.user.id },
    })

    if (!user) {
      return NextResponse.json(
        { error: 'Usuario no encontrado' },
        { status: 404 }
      )
    }

    // Crear posts con video e imagen (tipo celular vertical)
    const createdPosts = []
    for (const postData of postsWithMedia) {
      // Crear el post con el video como mediaUrl principal
      // Usaremos un formato JSON en mediaUrl para incluir múltiples medios
      // O mejor, crear dos posts separados o usar un campo JSON
      // Por ahora, vamos a usar mediaUrl para el video y agregar la imagen en un campo separado
      // Pero como el schema solo tiene mediaUrl, vamos a crear posts con ambos medios
      // usando un formato que el frontend pueda parsear
      
      // Opción: Crear el post con el video y luego actualizar para incluir la imagen
      // O mejor: usar mediaUrl para el video y crear un segundo post con la imagen
      // Pero el usuario quiere video E imagen en el mismo post
      
      // Almacenar video e imagen como JSON array en mediaUrl
      // El utils.ts lo transformará en mediaUrls array
      const mediaUrls = JSON.stringify([postData.videoUrl, postData.imageUrl])
      
      const post = await prisma.post.create({
        data: {
          content: postData.content,
          mediaUrl: mediaUrls, // Almacenar array JSON: [videoUrl, imageUrl]
          mediaType: 'video', // Tipo principal es video
          authorId: user.id,
        },
        select: postSelect,
      })
      
      // Transformar el post para incluir mediaUrls como array
      let parsedMediaUrls: string[] | null = null
      try {
        parsedMediaUrls = JSON.parse(post.mediaUrl || '[]')
      } catch {
        parsedMediaUrls = post.mediaUrl ? [post.mediaUrl] : null
      }
      
      createdPosts.push({
        ...post,
        mediaUrls: parsedMediaUrls,
      })
    }

    return NextResponse.json({
      message: 'Cinco posts con videos verticales creados exitosamente',
      posts: createdPosts,
    })
  } catch (error) {
    console.error('Error creating seed posts:', error)
    return NextResponse.json(
      { error: 'Error al crear posts de ejemplo' },
      { status: 500 }
    )
  }
}

