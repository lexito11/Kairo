'use client'

import Image from 'next/image'
import { useRouter } from 'next/navigation'

interface EventData {
  id: string
  title: string
  church: string
  location: string
  date: Date
  time: string
  category: string
  denomination: string
  image: string
  isLive: boolean
  distance?: number
  description: string
}

interface EventsUpcomingSectionProps {
  onEventClick?: (event: EventData) => void
}

export function EventsUpcomingSection({ onEventClick }: EventsUpcomingSectionProps) {
  const router = useRouter()
  
  // Datos mock de próximos eventos
  const upcomingEvents: EventData[] = [
    {
      id: '3',
      title: 'Conferencia Matrimonial "Unidos"',
      church: 'Iglesia Bautista Fe',
      location: 'Calle Principal 123, Centro',
      date: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000), // En 2 días
      time: '18:00 - 21:00',
      category: 'Conferencia',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1529070538774-1843cb3265df?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 8,
      description: 'Una conferencia diseñada para fortalecer los matrimonios cristianos.',
    },
    {
      id: '4',
      title: 'Noche de Alabanza Juvenil',
      church: 'Iglesia Bautista Juventud',
      location: 'Auditorio Norte',
      date: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000), // En 4 días
      time: '19:30',
      category: 'Jóvenes',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 12,
      description: 'Una noche especial de adoración y alabanza para jóvenes.',
    },
    {
      id: '5',
      title: 'Retiro de Parejas',
      church: 'Iglesia Bautista Central',
      location: 'Centro de Retiros',
      date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // En 7 días
      time: '09:00',
      category: 'Matrimonios',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1529070538774-1843cb3265df?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 15,
      description: 'Un retiro de fin de semana para parejas casadas.',
    },
  ]

  // Filtrar próximos eventos (futuros, no de hoy)
  const filteredEvents = upcomingEvents.filter(e => {
    const eventDate = new Date(e.date)
    eventDate.setHours(0, 0, 0, 0)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    return eventDate.getTime() > today.getTime()
  })

  if (filteredEvents.length === 0) {
    return null
  }

  // Helper para formatear fecha
  const formatDate = (date: Date) => {
    const months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC']
    return {
      month: months[date.getMonth()],
      day: date.getDate().toString(),
    }
  }

  return (
    <section className="mb-3 bg-white dark:bg-dark-bg">
      <div className="flex items-center justify-between mb-2 px-4">
        <h2 className="text-sm font-bold text-gray-900 dark:text-white">
          Próximos Eventos
        </h2>
      </div>

      <div className="flex gap-2 overflow-x-auto pb-2 px-4 scrollbar-hide">
        {filteredEvents.map((event) => {
          const dateInfo = formatDate(event.date)
          return (
            <div
              key={event.id}
              className="bg-white dark:bg-dark-card rounded-lg shadow-sm border border-gray-200 dark:border-dark-border overflow-hidden hover:shadow-md transition-shadow group cursor-pointer flex-shrink-0 w-52"
              onClick={() => onEventClick?.(event)}
            >
              <div className="relative h-32">
                <Image
                  src={event.image}
                  alt={event.title}
                  fill
                  className="object-cover group-hover:scale-105 transition-transform duration-500"
                />
                <div className="absolute top-1.5 left-1.5 bg-white/90 backdrop-blur text-center px-1 py-0.5 rounded shadow-sm">
                  <p className="text-[8px] font-bold text-red-500 leading-none">{dateInfo.month}</p>
                  <p className="text-[10px] font-bold text-gray-800 leading-none">{dateInfo.day}</p>
                </div>
              </div>
              <div className="p-2.5">
                <div className="flex items-center gap-1 mb-1">
                  <span className="text-[9px] font-bold text-primary-600 dark:text-primary-400 bg-primary-500/20 dark:bg-primary-500/20 px-1 py-0.5 rounded">
                    {event.denomination}
                  </span>
                  <span className="text-[9px] text-gray-700 dark:text-gray-400">• {event.category}</span>
                </div>
                <h3 className="font-bold text-xs text-gray-900 dark:text-white mb-1 line-clamp-2 leading-tight">{event.title}</h3>
                <p className="text-[10px] text-gray-700 dark:text-gray-400 mb-1.5 flex items-center gap-0.5 line-clamp-1">
                  <svg className="w-2.5 h-2.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                    />
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
                    />
                  </svg>
                  {event.location}
                </p>
                <button
                  onClick={(e) => {
                    e.stopPropagation()
                    if (onEventClick) {
                      onEventClick(event)
                    } else {
                      router.push('/events')
                    }
                  }}
                  className="w-full py-1 text-[10px] bg-primary-500 text-white font-medium rounded-md hover:bg-primary-600 transition-colors"
                >
                  Ver detalles
                </button>
              </div>
            </div>
          )
        })}
      </div>
    </section>
  )
}

