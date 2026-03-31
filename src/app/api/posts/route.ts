import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { uploadFile } from '@/lib/storage'
import {
  getPostsWithPagination,
  getPersonalizedFeed,
  getMyPostsIncludingAnonymous,
  postSelect,
  shapePostForClient,
} from './utils'
import { PostsResponse } from './types'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const page = parseInt(searchParams.get('page') || '1')
    const limit = Math.min(parseInt(searchParams.get('limit') || '10'), 100)
    const mine = searchParams.get('mine') === '1' || searchParams.get('mine') === 'true'

    // Obtener usuario actual si está autenticado (opcional)
    let currentUserId: string | null = null
    try {
      const session = await getServerSession(authOptions)
      currentUserId = session?.user?.id || null
    } catch (sessionError) {
      // Si no hay sesión, continuar sin userId (posts públicos)
      currentUserId = null
    }

    if (mine) {
      if (!currentUserId) {
        return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
      }
      const result = await getMyPostsIncludingAnonymous(page, limit, currentUserId)
      return NextResponse.json<PostsResponse>(result)
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
    const rawContent = (formData.get('content') as string) || ''
    const content = rawContent.trim()
    const isAnonymous = formData.get('isAnonymous') === 'true'
    const postKindRaw = (formData.get('postKind') as string) || 'post'
    const postKind = ['post', 'testimony', 'prayer'].includes(postKindRaw) ? postKindRaw : 'post'

    const fileList = formData
      .getAll('files')
      .filter((f): f is File => typeof f !== 'string' && f instanceof File && f.size > 0)
    const legacy = formData.get('file')
    if (legacy instanceof File && legacy.size > 0) {
      fileList.unshift(legacy)
    }

    if (!content && fileList.length === 0) {
      return NextResponse.json(
        { error: 'Escribe algo o adjunta al menos una foto o video.' },
        { status: 400 }
      )
    }

    if (content.length > 12000) {
      return NextResponse.json({ error: 'El texto es demasiado largo (máx. 12.000 caracteres).' }, { status: 400 })
    }

    if (fileList.length > 12) {
      return NextResponse.json({ error: 'Máximo 12 archivos por publicación.' }, { status: 400 })
    }

    let mediaUrl: string | null = null
    let mediaType: string | null = null

    if (fileList.length === 1) {
      const f = fileList[0]
      mediaUrl = await uploadFile(f, `posts/${session.user.id}`)
      mediaType = f.type.startsWith('video/') ? 'video' : 'image'
    } else if (fileList.length > 1) {
      const urls: string[] = []
      for (const f of fileList) {
        urls.push(await uploadFile(f, `posts/${session.user.id}`))
      }
      mediaUrl = JSON.stringify(urls)
      const hasVideo = fileList.some((f) => f.type.startsWith('video/'))
      mediaType = hasVideo ? 'video' : 'image'
    }

    const selectWithLike = {
      ...postSelect,
      likes: {
        where: { authorId: session.user.id },
        select: { id: true },
      },
    }

    const post = await prisma.post.create({
      data: {
        content: content || '',
        mediaUrl,
        mediaType,
        isAnonymous,
        postKind,
        authorId: session.user.id,
      } as any,
      select: selectWithLike,
    })

    return NextResponse.json(shapePostForClient(post, session.user.id))
  } catch (error) {
    console.error('Error creating post:', error)
    return NextResponse.json(
      { error: 'Error al crear post' },
      { status: 500 }
    )
  }
}

