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

interface EventsTodaySectionProps {
  onEventClick?: (event: EventData) => void
}

export function EventsTodaySection({ onEventClick }: EventsTodaySectionProps) {
  const router = useRouter()
  
  // Datos mock de eventos de hoy
  const todayEvents: EventData[] = [
    {
      id: '1',
      title: 'Adoración y Palabra',
      church: 'Iglesia Bautista Vida',
      location: 'Iglesia Bautista Vida (3km)',
      date: new Date(),
      time: '10:00',
      category: 'Culto Dominical',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: true,
      distance: 3,
      description: 'Únete a nosotros para un tiempo especial de adoración y enseñanza de la Palabra de Dios.',
    },
    {
      id: '2',
      title: 'Estudio de Romanos 8',
      church: 'Iglesia Bautista Central',
      location: 'Iglesia Bautista Central',
      date: new Date(),
      time: '19:00',
      category: 'Estudio Bíblico',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1544427920-c49ccfb85579?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: true,
      distance: 5,
      description: 'Estudio profundo del capítulo 8 de la carta a los Romanos.',
    },
  ]

  // Filtrar eventos de hoy
  const filteredEvents = todayEvents.filter(e => {
    const eventDate = new Date(e.date)
    eventDate.setHours(0, 0, 0, 0)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    return eventDate.getTime() === today.getTime()
  })

  if (filteredEvents.length === 0) {
    return null
  }

  return (
    <section className="mb-3 bg-white dark:bg-dark-bg">
      <div className="flex items-center justify-between mb-2 px-4">
        <h2 className="text-sm font-bold text-gray-900 dark:text-white flex items-center gap-1">
          <span className="relative flex h-1.5 w-1.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-red-500"></span>
          </span>
          Hoy
        </h2>
      </div>

      <div className="flex gap-2 overflow-x-auto pb-2 px-4 scrollbar-hide">
        {filteredEvents.map((event) => (
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
              {event.isLive && (
                <div className="absolute top-1.5 left-1.5 bg-red-600 text-white text-[9px] font-bold px-1 py-0.5 rounded flex items-center gap-0.5 shadow-sm">
                  <svg className="w-2 h-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
                  </svg>
                  EN CURSO
                </div>
              )}
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
        ))}
      </div>
    </section>
  )
}

