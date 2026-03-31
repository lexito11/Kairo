import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function POST(
  _request: NextRequest,
  { params }: { params: { userId: string } }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
    }

    const followingId = params.userId
    if (followingId === session.user.id) {
      return NextResponse.json({ error: 'No puedes agregarte a ti mismo' }, { status: 400 })
    }

    const target = await prisma.user.findUnique({ where: { id: followingId } })
    if (!target) {
      return NextResponse.json({ error: 'Usuario no encontrado' }, { status: 404 })
    }

    await prisma.follow.upsert({
      where: {
        followerId_followingId: {
          followerId: session.user.id,
          followingId,
        },
      },
      create: {
        followerId: session.user.id,
        followingId,
      },
      update: {},
    })

    return NextResponse.json({ ok: true })
  } catch (error) {
    console.error('POST follow:', error)
    return NextResponse.json({ error: 'Error al agregar' }, { status: 500 })
  }
}

export async function DELETE(
  _request: NextRequest,
  { params }: { params: { userId: string } }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 })
    }

    const followingId = params.userId

    await prisma.follow.deleteMany({
      where: {
        followerId: session.user.id,
        followingId,
      },
    })

    return NextResponse.json({ ok: true })
  } catch (error) {
    console.error('DELETE follow:', error)
    return NextResponse.json({ error: 'Error al quitar' }, { status: 500 })
  }
}
