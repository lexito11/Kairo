import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET(
  _request: NextRequest,
  { params }: { params: { userId: string } }
) {
  try {
    const userId = params.userId
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        username: true,
        image: true,
        bio: true,
        _count: {
          select: {
            following: true,
            followers: true,
          },
        },
      },
    })

    if (!user) {
      return NextResponse.json({ error: 'Usuario no encontrado' }, { status: 404 })
    }

    const session = await getServerSession(authOptions)
    let viewerHasAdded = false
    if (session?.user?.id && session.user.id !== userId) {
      const row = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: session.user.id,
            followingId: userId,
          },
        },
      })
      viewerHasAdded = !!row
    }

    return NextResponse.json({
      user: {
        id: user.id,
        name: user.name,
        username: user.username,
        image: user.image,
        bio: user.bio,
      },
      agregados: user._count.following,
      teAgregaron: user._count.followers,
      viewerHasAdded,
    })
  } catch (error) {
    console.error('GET /api/users/[userId]:', error)
    return NextResponse.json({ error: 'Error al cargar perfil' }, { status: 500 })
  }
}
