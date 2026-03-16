import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { uploadFile } from '@/lib/storage'
import { getPostsWithPagination, getPersonalizedFeed, postSelect } from './utils'
import { PostsResponse } from './types'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const page = parseInt(searchParams.get('page') || '1')
    const limit = parseInt(searchParams.get('limit') || '10')

    // Obtener usuario actual si está autenticado (opcional)
    let currentUserId: string | null = null
    try {
      const session = await getServerSession(authOptions)
      currentUserId = session?.user?.id || null
    } catch (sessionError) {
      // Si no hay sesión, continuar sin userId (posts públicos)
      currentUserId = null
    }

    let result: PostsResponse
    if (currentUserId) {
      try {
        result = await getPersonalizedFeed(page, limit, currentUserId)
      } catch (feedError) {
        console.warn('Feed personalizado no disponible, usando feed cronológico:', feedError)
        result = await getPostsWithPagination(page, limit, currentUserId)
      }
    } else {
      result = await getPostsWithPagination(page, limit, null)
    }

    return NextResponse.json<PostsResponse>(result)
  } catch (error) {
    console.error('Error fetching posts:', error)
    return NextResponse.json(
      { error: 'Error al cargar posts' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'No autorizado' },
        { status: 401 }
      )
    }

    const formData = await request.formData()
    const content = formData.get('content') as string
    const file = formData.get('file') as File | null

    if (!content && !file) {
      return NextResponse.json(
        { error: 'Contenido o archivo requerido' },
        { status: 400 }
      )
    }

    let mediaUrl: string | null = null
    let mediaType: string | null = null

    if (file) {
      mediaUrl = await uploadFile(file, `posts/${session.user.id}`)
      mediaType = file.type.startsWith('video/') ? 'video' : 'image'
    }

    const post = await prisma.post.create({
      data: {
        content: content || '',
        mediaUrl,
        mediaType,
        authorId: session.user.id,
      },
      select: postSelect,
    })

    return NextResponse.json(post)
  } catch (error) {
    console.error('Error creating post:', error)
    return NextResponse.json(
      { error: 'Error al crear post' },
      { status: 500 }
    )
  }
}

