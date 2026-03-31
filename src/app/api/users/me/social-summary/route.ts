import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

/** Resumen ligero para el perfil: notificaciones sin leer + cantidad de amigos mutuos */
export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
    }

    const userId = session.user.id

    const [unreadCount, outgoing, followMeRows] = await Promise.all([
      prisma.follow.count({
        where: { followingId: userId, seenByFolloweeAt: null },
      }),
      prisma.follow.findMany({
        where: { followerId: userId },
        select: { followingId: true },
      }),
      prisma.follow.findMany({
        where: { followingId: userId },
        select: { followerId: true },
      }),
    ])

    const iFollow = new Set(outgoing.map((f) => f.followingId))
    const friendsCount = followMeRows.filter((f) => iFollow.has(f.followerId)).length

    return NextResponse.json({ unreadCount, friendsCount })
  } catch (error) {
    console.error('GET /api/users/me/social-summary:', error)
    return NextResponse.json({ error: 'Error al cargar' }, { status: 500 })
  }
}
