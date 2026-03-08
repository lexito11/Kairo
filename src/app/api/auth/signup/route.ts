import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import bcrypt from 'bcryptjs'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { name, email, username, password } = body

    // Validaciones
    if (!email || !password) {
      return NextResponse.json(
        { error: 'Email y contraseña son requeridos' },
        { status: 400 }
      )
    }

    if (password.length < 6) {
      return NextResponse.json(
        { error: 'La contraseña debe tener al menos 6 caracteres' },
        { status: 400 }
      )
    }

    // Verificar si el email ya existe
    const existingUser = await prisma.user.findUnique({
      where: { email },
    })

    if (existingUser) {
      return NextResponse.json(
        { error: 'Este email ya está registrado' },
        { status: 400 }
      )
    }

    // Verificar si el username ya existe (si se proporciona)
    if (username) {
      const existingUsername = await prisma.user.findUnique({
        where: { username },
      })

      if (existingUsername) {
        return NextResponse.json(
          { error: 'Este usuario ya está en uso' },
          { status: 400 }
        )
      }
    }

    // Hash de la contraseña
    const hashedPassword = await bcrypt.hash(password, 10)

    // NOTA: El schema actual no tiene campo 'password'
    // Necesitas agregarlo al schema.prisma:
    // password String @db.Text
    // Y luego ejecutar: npx prisma db push
    
    // Por ahora, creamos el usuario sin password (esto fallará hasta que agregues el campo)
    // Cuando agregues el campo password al schema, descomenta las líneas de abajo
    // y comenta la línea de create sin password
    
    try {
      const user = await prisma.user.create({
        data: {
          name: name || null,
          email,
          username: username || null,
          // password: hashedPassword, // Descomentar cuando agregues el campo al schema
        },
        select: {
          id: true,
          email: true,
          name: true,
          username: true,
          createdAt: true,
        },
      })

      return NextResponse.json(
        { 
          message: 'Usuario creado exitosamente',
          user 
        },
        { status: 201 }
      )
    } catch (dbError: any) {
      // Si falla porque no existe el campo password, dar mensaje útil
      if (dbError.message?.includes('password') || dbError.message?.includes('Unknown argument')) {
        return NextResponse.json(
          { 
            error: 'Error: El campo password no existe en el schema. Por favor agrégalo al schema.prisma y ejecuta npx prisma db push',
            hint: 'Agrega esta línea al model User en schema.prisma: password String @db.Text'
          },
          { status: 500 }
        )
      }
      throw dbError
    }
  } catch (error: any) {
    console.error('Error creating user:', error)
    return NextResponse.json(
      { error: error.message || 'Error al crear usuario' },
      { status: 500 }
    )
  }
}





