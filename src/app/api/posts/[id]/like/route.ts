import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { postSelect } from '../../utils'
import { LikePostResponse } from './types'

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'No autorizado' },
        { status: 401 }
      )
    }

    const postId = params.id
    const userId = session.user.id

    // Verificar si ya existe el like
    const existingLike = await prisma.like.findUnique({
      where: {
        authorId_postId: {
          authorId: userId,
          postId,
        },
      },
    })

    if (existingLike) {
      // Eliminar like
      await prisma.like.delete({
        where: {
          id: existingLike.id,
        },
      })
    } else {
      // Crear like
      await prisma.like.create({
        data: {
          authorId: userId,
          postId,
        },
      })
    }

    // Obtener post actualizado con información de like del usuario
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: {
        ...postSelect,
        likes: {
          where: {
            authorId: userId,
          },
          select: {
            id: true,
          },
        },
      },
    })

    if (!post) {
      return NextResponse.json(
        { error: 'Post no encontrado' },
        { status: 404 }
      )
    }

    // Transformar para incluir isLiked
    const postWithLike = {
      ...post,
      isLiked: (post as any).likes && (post as any).likes.length > 0,
      likes: undefined, // Eliminar el array de likes
    }

    return NextResponse.json<LikePostResponse>(postWithLike)
  } catch (error) {
    console.error('Error toggling like:', error)
    return NextResponse.json(
      { error: 'Error al dar like' },
      { status: 500 }
    )
  }
}

