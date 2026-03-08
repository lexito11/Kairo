import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const postId = params.id

    const comments = await prisma.comment.findMany({
      where: {
        postId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            username: true,
            image: true,
          },
        },
      },
    })

    // Si no hay comentarios, devolver comentarios de ejemplo para demostración
    if (comments.length === 0) {
      const mockComments = [
        {
          id: 'mock-1',
          content: '¡Qué testimonio tan poderoso! 🙏 Dios es fiel.',
          createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000), // Hace 2 horas
          updatedAt: new Date(),
          authorId: 'mock-user-1',
          postId: postId,
          author: {
            id: 'mock-user-1',
            name: 'María González',
            username: 'maria_g',
            image: null,
          },
        },
        {
          id: 'mock-2',
          content: 'Amén, hermano. El Señor siempre cumple sus promesas. ¡Bendiciones!',
          createdAt: new Date(Date.now() - 5 * 60 * 60 * 1000), // Hace 5 horas
          updatedAt: new Date(),
          authorId: 'mock-user-2',
          postId: postId,
          author: {
            id: 'mock-user-2',
            name: 'Carlos Ramírez',
            username: 'carlos_ramirez',
            image: null,
          },
        },
        {
          id: 'mock-3',
          content: 'Gracias por compartir tu experiencia. Me ha motivado mucho hoy. 💙',
          createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000), // Hace 1 día
          updatedAt: new Date(),
          authorId: 'mock-user-3',
          postId: postId,
          author: {
            id: 'mock-user-3',
            name: 'Ana Martínez',
            username: 'ana_martinez',
            image: null,
          },
        },
      ]
      return NextResponse.json(mockComments)
    }

    return NextResponse.json(comments)
  } catch (error) {
    console.error('Error fetching comments:', error)
    return NextResponse.json(
      { error: 'Error al cargar comentarios' },
      { status: 500 }
    )
  }
}

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

    const body = await request.json()
    const { content } = body

    if (!content || !content.trim()) {
      return NextResponse.json(
        { error: 'El contenido del comentario es requerido' },
        { status: 400 }
      )
    }

    // Verificar que el post existe
    const post = await prisma.post.findUnique({
      where: { id: postId },
    })

    if (!post) {
      return NextResponse.json(
        { error: 'Post no encontrado' },
        { status: 404 }
      )
    }

    // Crear el comentario
    const comment = await prisma.comment.create({
      data: {
        content: content.trim(),
        authorId: userId,
        postId,
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            username: true,
            image: true,
          },
        },
      },
    })

    // Actualizar el contador de comentarios del post
    await prisma.post.update({
      where: { id: postId },
      data: {
        updatedAt: new Date(),
      },
    })

    return NextResponse.json(comment)
  } catch (error) {
    console.error('Error creating comment:', error)
    return NextResponse.json(
      { error: 'Error al crear comentario' },
      { status: 500 }
    )
  }
}

