import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { getPostsByIds } from '../utils'

/** GET /api/posts/saved?ids=id1,id2,id3 — posts guardados para la pestaña Guardados del perfil */
export async function GET(request: NextRequest) {
  try {
    const idsParam = request.nextUrl.searchParams.get('ids') || ''
    const ids = idsParam.split(',').map((id) => id.trim()).filter(Boolean)

    let currentUserId: string | null = null
    try {
      const session = await getServerSession(authOptions)
      currentUserId = session?.user?.id || null
    } catch {
      currentUserId = null
    }

    const posts = await getPostsByIds(ids, currentUserId)
    return NextResponse.json({ posts })
  } catch (error) {
    console.error('Error fetching saved posts:', error)
    return NextResponse.json(
      { error: 'Error al cargar guardados' },
      { status: 500 }
    )
  }
}
