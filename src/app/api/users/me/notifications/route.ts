import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

/** Personas que te agregaron (te siguen) + si ya es mutuo */
export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
    }

    const userId = session.user.id

    const [follows, myFollowing] = await Promise.all([
      prisma.follow.findMany({
        where: { followingId: userId },
        include: {
          follower: {
            select: { id: true, name: true, username: true, image: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.follow.findMany({
        where: { followerId: userId },
        select: { followingId: true },
      }),
    ])

    const followingSet = new Set(myFollowing.map((f) => f.followingId))

    const items = follows.map((f) => ({
      id: f.follower.id,
      name: f.follower.name,
      username: f.follower.username,
      image: f.follower.image,
      isMutual: followingSet.has(f.followerId),
      followId: f.id,
      createdAt: f.createdAt.toISOString(),
    }))

    const unreadCount = follows.filter((f) => f.seenByFolloweeAt === null).length

    return NextResponse.json({ items, unreadCount })
  } catch (error) {
    console.error('GET /api/users/me/notifications:', error)
    return NextResponse.json({ error: 'Error al cargar notificaciones' }, { status: 500 })
  }
}

/** Marcar todas las notificaciones de “quien te agregó” como vistas */
export async function POST() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
    }

    const userId = session.user.id
    const now = new Date()

    await prisma.follow.updateMany({
      where: {
        followingId: userId,
        seenByFolloweeAt: null,
      },
      data: { seenByFolloweeAt: now },
    })

    return NextResponse.json({ ok: true })
  } catch (error) {
    console.error('POST /api/users/me/notifications:', error)
    return NextResponse.json({ error: 'Error al actualizar' }, { status: 500 })
  }
}
