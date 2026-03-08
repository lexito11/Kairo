import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { postSelect } from '../utils'

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const postId = params.id

    // Obtener usuario actual si está autenticado (opcional)
    let currentUserId: string | null = null
    try {
      const session = await getServerSession(authOptions)
      currentUserId = session?.user?.id || null
    } catch (sessionError) {
      currentUserId = null
    }

    // Crear select personalizado que incluye likes del usuario actual
    const selectWithLike = currentUserId ? {
      ...postSelect,
      likes: {
        where: {
          authorId: currentUserId,
        },
        select: {
          id: true,
        },
      },
    } : postSelect

    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: selectWithLike,
    })

    if (!post) {
      return NextResponse.json(
        { error: 'Post no encontrado' },
        { status: 404 }
      )
    }

    // Transformar post para incluir isLiked
    const postWithLike = {
      ...post,
      isLiked: currentUserId ? ((post as any).likes && (post as any).likes.length > 0) : false,
      likes: undefined, // Eliminar el array de likes del objeto
    }

    return NextResponse.json(postWithLike)
  } catch (error) {
    console.error('Error fetching post:', error)
    return NextResponse.json(
      { error: 'Error al cargar post' },
      { status: 500 }
    )
  }
}






