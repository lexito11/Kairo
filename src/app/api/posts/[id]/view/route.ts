import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

/**
 * Registra tiempo de reproducción (watch time) para personalizar el feed.
 * POST body: { watchedSeconds: number }
 */
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ ok: true })
    }

    const postId = params.id
    const body = await request.json().catch(() => ({}))
    const watchedSeconds = Math.max(0, Math.floor(Number(body.watchedSeconds) || 0))

    if (watchedSeconds <= 0) return NextResponse.json({ ok: true })

    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { id: true },
    })
    if (!post) return NextResponse.json({ ok: true })

    await prisma.postView.create({
      data: {
        userId: session.user.id,
        postId,
        watchedSeconds,
      },
    })

    return NextResponse.json({ ok: true })
  } catch {
    return NextResponse.json({ ok: true })
  }
}
