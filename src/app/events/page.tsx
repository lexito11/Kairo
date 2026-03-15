'use client'

import Image from 'next/image'
import Link from 'next/link'
import { BottomNavigation } from '@/components/templates/BottomNavigation'
import { DenominationSelector } from '@/components/organisms/DenominationSelector/DenominationSelector'
import { useState, useEffect, useRef } from 'react'
import { useSession } from 'next-auth/react'

const denominationNames: Record<string, string> = {
  bautista: 'Bautista',
  pentecostal: 'Pentecostal',
  presbiteriano: 'Presbiteriano',
  metodista: 'Metodista',
  luterano: 'Luterano',
  anglicano: 'Anglicano',
  catolico: 'Católico',
  otra: 'Otra',
}

const EVENT_CATEGORIES = [
  'Educación y Capacitación',
  'Conferencias y Charlas',
  'Deportes y Actividad Física',
  'Arte y Cultura',
  'Social y Familiar',
  'Salud y Bienestar',
  'Servicio y Acción Social',
  'Gestión y Planeación',
]

type FilterType = 'todos' | 'hoy' | 'enVivo' | 'proximos'

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

export default function EventsPage() {
  const { data: session } = useSession()
  const [selectedDenomination, setSelectedDenomination] = useState<string | null>(null)
  const [showDenominationDropdown, setShowDenominationDropdown] = useState(false)
  const [showInitialSelector, setShowInitialSelector] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [activeFilter, setActiveFilter] = useState<FilterType>('todos')
  const [eventScope, setEventScope] = useState<'cristianos' | 'particulares' | 'iglesia'>('cristianos')
  const [selectedEvent, setSelectedEvent] = useState<EventData | null>(null)
  const [showChurchRegistration, setShowChurchRegistration] = useState(false)
  const [showFilterPanel, setShowFilterPanel] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [churchFormData, setChurchFormData] = useState({
    name: '',
    denomination: '',
    city: '',
    password: ''
  })
  const [showCreateParticularEvent, setShowCreateParticularEvent] = useState(false)
  const [particularEventForm, setParticularEventForm] = useState({
    title: '',
    category: '',
    location: '',
    date: '',
    description: ''
  })
  const dropdownRef = useRef<HTMLDivElement>(null)

  // Datos mock de eventos
  const allEvents: EventData[] = [
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
      description: 'Únete a nosotros para un tiempo especial de adoración y enseñanza de la Palabra de Dios. Será un momento de comunión, alabanza y reflexión bíblica que fortalecerá tu fe y te acercará más al Señor.',
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
      description: 'Estudio profundo del capítulo 8 de la carta a los Romanos, explorando temas como la vida en el Espíritu, la seguridad de la salvación y el amor de Dios. Trae tu Biblia y prepárate para crecer en el conocimiento de las Escrituras.',
    },
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
      description: 'Una conferencia diseñada para fortalecer los matrimonios cristianos. Aprenderás principios bíblicos para construir una relación sólida, mejorar la comunicación y mantener a Cristo en el centro de tu matrimonio.',
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
      description: 'Una noche especial de adoración y alabanza para jóvenes. Ven y experimenta la presencia de Dios a través de música contemporánea, testimonio y un mensaje relevante para tu vida. Invita a tus amigos y juntos adoremos al Señor.',
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
      description: 'Un retiro de fin de semana para parejas casadas. Tiempo de reflexión, enseñanza bíblica sobre el matrimonio, actividades recreativas y momentos de intimidad espiritual. Un espacio para renovar y fortalecer tu relación matrimonial.',
    },
    {
      id: '6',
      title: 'Encuentro de Solteros',
      church: 'Iglesia Bautista Esperanza',
      location: 'Salón Principal',
      date: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), // En 5 días
      time: '18:00',
      category: 'Solteros',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 10,
      description: 'Un espacio de comunión y crecimiento para solteros. Compartiremos sobre el propósito de Dios para la soltería, cómo vivir una vida plena en Cristo y prepararnos para el futuro que Él tiene para nosotros.',
    },
    {
      id: '7',
      title: 'Taller para Solteros: Relaciones Sanas',
      church: 'Iglesia Bautista Gracia',
      location: 'Aula 3',
      date: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000), // En 10 días
      time: '19:00',
      category: 'Solteros',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1529070538774-1843cb3265df?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 6,
      description: 'Aprende principios bíblicos para construir relaciones saludables. Hablaremos sobre amistad, límites, comunicación y cómo honrar a Dios en todas nuestras relaciones.',
    },
    {
      id: '8',
      title: 'Retiro de Matrimonios',
      church: 'Iglesia Bautista Central',
      location: 'Centro de Retiros',
      date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000), // En 14 días
      time: '09:00',
      category: 'Casados',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1529070538774-1843cb3265df?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 15,
      description: 'Un fin de semana completo para parejas casadas. Tiempo de renovación espiritual, talleres prácticos, actividades en pareja y momentos de adoración. Fortalece tu matrimonio con principios bíblicos.',
    },
    {
      id: '9',
      title: 'Cena para Matrimonios',
      church: 'Iglesia Bautista Fe',
      location: 'Salón de Eventos',
      date: new Date(Date.now() + 9 * 24 * 60 * 60 * 1000), // En 9 días
      time: '19:00',
      category: 'Casados',
      denomination: 'Bautista',
      image: 'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      isLive: false,
      distance: 7,
      description: 'Una noche especial para parejas casadas. Disfruta de una cena romántica, un mensaje inspirador y tiempo de comunión con otras parejas. Celebra el regalo del matrimonio.',
    },
  ]

  // Estado para los contadores de asistencia - inicializar como objeto vacío
  const [attendanceCounts, setAttendanceCounts] = useState<Record<string, { attending: number; notAttending: number; userStatus: 'attending' | 'notAttending' | null }>>({})
  
  // Inicializar los contadores cuando el componente se monta
  useEffect(() => {
    const initial: Record<string, { attending: number; notAttending: number; userStatus: 'attending' | 'notAttending' | null }> = {}
    allEvents.forEach(event => {
      initial[event.id] = {
        attending: Math.floor(Math.random() * 50) + 10,
        notAttending: Math.floor(Math.random() * 20) + 1,
        userStatus: null
      }
    })
    setAttendanceCounts(initial)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  
  // Función para manejar el clic en "Asistiré"
  const handleAttending = (eventId: string) => {
    setAttendanceCounts(prev => {
      const current = prev[eventId] || { attending: 0, notAttending: 0, userStatus: null }
      
      if (current.userStatus === 'attending') {
        // Si ya estaba marcado como asistiré, desmarcarlo
        return {
          ...prev,
          [eventId]: {
            ...current,
            attending: current.attending - 1,
            userStatus: null
          }
        }
      } else if (current.userStatus === 'notAttending') {
        // Si estaba marcado como no asistiré, cambiar a asistiré
        return {
          ...prev,
          [eventId]: {
            ...current,
            attending: current.attending + 1,
            notAttending: current.notAttending - 1,
            userStatus: 'attending'
          }
        }
      } else {
        // Si no estaba marcado, marcarlo como asistiré
        return {
          ...prev,
          [eventId]: {
            ...current,
            attending: current.attending + 1,
            userStatus: 'attending'
          }
        }
      }
    })
  }
  
  // Función para manejar el clic en "No asistiré"
  const handleNotAttending = (eventId: string) => {
    setAttendanceCounts(prev => {
      const current = prev[eventId] || { attending: 0, notAttending: 0, userStatus: null }
      
      if (current.userStatus === 'notAttending') {
        // Si ya estaba marcado como no asistiré, desmarcarlo
        return {
          ...prev,
          [eventId]: {
            ...current,
            notAttending: current.notAttending - 1,
            userStatus: null
          }
        }
      } else if (current.userStatus === 'attending') {
        // Si estaba marcado como asistiré, cambiar a no asistiré
        return {
          ...prev,
          [eventId]: {
            ...current,
            attending: current.attending - 1,
            notAttending: current.notAttending + 1,
            userStatus: 'notAttending'
          }
        }
      } else {
        // Si no estaba marcado, marcarlo como no asistiré
        return {
          ...prev,
          [eventId]: {
            ...current,
            notAttending: current.notAttending + 1,
            userStatus: 'notAttending'
          }
        }
      }
    })
  }

  // Función para filtrar eventos por término de búsqueda
  const filterBySearch = (events: EventData[]): EventData[] => {
    if (!searchTerm.trim()) return events
    
    const term = searchTerm.toLowerCase().trim()
    return events.filter(event => 
      event.title.toLowerCase().includes(term) ||
      event.church.toLowerCase().includes(term) ||
      event.location.toLowerCase().includes(term) ||
      event.category.toLowerCase().includes(term) ||
      event.description.toLowerCase().includes(term)
    )
  }

  // Función para filtrar eventos
  const getFilteredEvents = (): EventData[] => {
    const now = new Date()
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    let events: EventData[] = []

    switch (activeFilter) {
      case 'hoy':
        events = allEvents.filter(event => {
          const eventDate = new Date(event.date)
          eventDate.setHours(0, 0, 0, 0)
          const isToday = eventDate.getTime() === today.getTime()
          
          // Si es hoy, mostrar solo los que están en curso o les faltan horas
          if (isToday) {
            // Si está en vivo, mostrarlo
            if (event.isLive) return true
            
            // Si no está en vivo pero es hoy, verificar si la hora del evento es mayor a la hora actual
            const eventTime = event.time.split('-')[0].trim() // Tomar la primera hora si hay rango
            const [hours, minutes] = eventTime.split(':').map(Number)
            const eventDateTime = new Date(event.date)
            eventDateTime.setHours(hours, minutes || 0, 0, 0)
            
            // Mostrar si el evento es hoy y aún no ha pasado
            return eventDateTime >= now
          }
          
          return false
        })
        break
      
      case 'enVivo':
        events = allEvents.filter(event => event.isLive)
        break
      
      case 'proximos':
        events = allEvents.filter(event => {
          const eventDate = new Date(event.date)
          eventDate.setHours(0, 0, 0, 0)
          const today = new Date()
          today.setHours(0, 0, 0, 0)
          return eventDate.getTime() > today.getTime()
        })
        break
      
      default:
        events = allEvents
    }

    // Aplicar filtro de búsqueda
    return filterBySearch(events)
  }

  const filteredEvents = getFilteredEvents()

  // Helper para formatear fecha
  const formatDate = (date: Date) => {
    const months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC']
    return {
      month: months[date.getMonth()],
      day: date.getDate().toString(),
    }
  }

  // Helper para obtener color de categoría
  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'Conferencia':
        return 'text-amber-400 bg-amber-500/20'
      case 'Jóvenes':
        return 'text-emerald-400 bg-emerald-500/20'
      case 'Matrimonios':
        return 'text-pink-400 bg-pink-500/20'
      default:
        return 'text-primary-400 bg-primary-500/20'
    }
  }

  // Verificar si el usuario ya tiene una denominación guardada
  useEffect(() => {
    // Si session es null/undefined, también establecer loading como false
    if (session === undefined) {
      // Aún está cargando la sesión
      return
    }
    
    if (session?.user?.id) {
      const savedDenomination = localStorage.getItem(`denomination_${session.user.id}`)
      if (savedDenomination) {
        setSelectedDenomination(savedDenomination)
        setIsLoading(false)
      } else {
        setShowInitialSelector(true)
        setIsLoading(false)
      }
    } else {
      setIsLoading(false)
    }
  }, [session])

  const handleDenominationSelect = (denomination: string) => {
    if (session?.user?.id) {
      localStorage.setItem(`denomination_${session.user.id}`, denomination)
      setSelectedDenomination(denomination)
      setShowInitialSelector(false)
    }
  }

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDenominationDropdown(false)
      }
    }

    if (showDenominationDropdown) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showDenominationDropdown])

  // Mostrar selector inicial si no tiene denominación
  if (showInitialSelector && !isLoading) {
    return (
      <>
        <DenominationSelector onSelect={handleDenominationSelect} />
        <BottomNavigation />
      </>
    )
  }

  // Mostrar loading
  if (isLoading) {
    return (
      <div className="min-h-screen bg-white dark:bg-dark-bg flex items-center justify-center">
        <div className="text-gray-900 dark:text-white">Cargando...</div>
      </div>
    )
  }

  const displayDenomination = selectedDenomination 
    ? denominationNames[selectedDenomination] || selectedDenomination 
    : 'Bautista'

  return (
    <div className="min-h-screen bg-white dark:bg-dark-bg pb-24">
      <div className="max-w-md mx-auto">
        {/* Header */}
        <header className="bg-white dark:bg-dark-bg border-b border-gray-200 dark:border-dark-border sticky top-0 z-10 px-4 py-4">
          <div className="flex flex-col gap-4">
            
            {/* Cristianos | Particulares | Iglesia (si pertenece) */}
            <div className="flex items-center gap-6 border-b border-gray-200 dark:border-dark-border pb-2">
              <button
                onClick={() => setEventScope('cristianos')}
                className={`text-base font-bold transition-colors pb-2 border-b-2 -mb-0.5 ${
                  eventScope === 'cristianos'
                    ? 'text-gray-900 dark:text-white border-gray-900 dark:border-white'
                    : 'text-gray-500 dark:text-gray-400 border-transparent hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                Cristianos
              </button>
              <button
                onClick={() => setEventScope('particulares')}
                className={`text-base font-bold transition-colors pb-2 border-b-2 -mb-0.5 ${
                  eventScope === 'particulares'
                    ? 'text-gray-900 dark:text-white border-gray-900 dark:border-white'
                    : 'text-gray-500 dark:text-gray-400 border-transparent hover:text-gray-700 dark:hover:text-gray-300'
                }`}
              >
                Particulares
              </button>
              {selectedDenomination && eventScope !== 'particulares' && (
                <button
                  onClick={() => setEventScope('iglesia')}
                  className={`text-base font-bold transition-colors pb-2 border-b-2 -mb-0.5 ${
                    eventScope === 'iglesia'
                      ? 'text-gray-900 dark:text-white border-gray-900 dark:border-white'
                      : 'text-gray-500 dark:text-gray-400 border-transparent hover:text-gray-700 dark:hover:text-gray-300'
                  }`}
                >
                  {displayDenomination}
                </button>
              )}
            </div>

            {/* Denomination Selector (no mostrar en Particulares) */}
            {eventScope !== 'particulares' && (
            <div className="flex items-center gap-3">
              <div className="relative group" ref={dropdownRef}>
                <button 
                  onClick={() => setShowDenominationDropdown(!showDenominationDropdown)}
                  className="flex items-center gap-2 bg-primary-500/20 hover:bg-primary-500/30 text-primary-400 px-4 py-2 rounded-full transition-colors border border-primary-500/30"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                  <span className="font-bold">{displayDenomination}</span>
                  <svg className="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {/* Dropdown */}
                {showDenominationDropdown && (
                  <div className="absolute top-full left-0 mt-2 w-64 bg-white dark:bg-dark-card rounded-xl shadow-xl border border-gray-200 dark:border-dark-border p-2 z-50">
                    <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 px-3 py-2 uppercase tracking-wider">Tu Denominación</div>
                    {selectedDenomination && (
                      <div className="px-3 py-2 mb-2">
                        <div className="flex items-center gap-3 px-3 py-2 bg-primary-500/20 text-primary-400 rounded-lg">
                          <div className={`w-2 h-2 rounded-full ${
                            selectedDenomination === 'bautista' ? 'bg-primary-500' :
                            selectedDenomination === 'pentecostal' ? 'bg-red-500' :
                            selectedDenomination === 'presbiteriano' ? 'bg-green-500' :
                            selectedDenomination === 'metodista' ? 'bg-blue-500' :
                            selectedDenomination === 'luterano' ? 'bg-purple-500' :
                            selectedDenomination === 'anglicano' ? 'bg-yellow-500' :
                            selectedDenomination === 'catolico' ? 'bg-indigo-500' :
                            'bg-gray-500'
                          }`}></div>
                          <span className="font-medium">{displayDenomination}</span>
                          <svg className="w-4 h-4 ml-auto text-primary-400" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                          </svg>
                        </div>
                      </div>
                    )}
                    <div className="px-3 py-2 mb-2 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
                      <p className="text-xs text-yellow-400 font-medium mb-1">⚠️ No se puede cambiar</p>
                      <p className="text-xs text-gray-400">
                        Tu denominación no se puede cambiar directamente. Si necesitas cambiarla, debes hacer una petición válida.
                      </p>
                    </div>
                    <div className="mt-2 pt-2 border-t border-dark-border">
                      <button
                        onClick={() => {
                          setShowDenominationDropdown(false)
                          // Aquí podrías abrir un modal para solicitar cambio
                          alert('Para cambiar tu denominación, por favor contacta al soporte explicando el motivo del cambio. Esta solicitud será revisada por nuestro equipo.')
                        }}
                        className="w-full text-sm text-primary-400 hover:text-primary-300 hover:bg-primary-500/10 text-center py-2 rounded-lg transition-colors"
                      >
                        Solicitar cambio de denominación
                      </button>
                    </div>
                  </div>
                )}
              </div>
              <span className="text-gray-400 text-sm hidden sm:inline">Mostrando eventos de tu fe</span>
            </div>
            )}

            {/* Actions */}
            <div className="flex items-center gap-3">
              <button className="w-10 h-10 rounded-full bg-gray-100 dark:bg-dark-hover hover:bg-gray-200 dark:hover:bg-dark-border flex items-center justify-center text-gray-600 dark:text-gray-400 transition-colors relative">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white dark:border-dark-bg"></span>
              </button>
              
              {/* Buscador */}
              <div className="flex-1 max-w-xs">
                <div className="relative">
                  <input
                    type="text"
                    placeholder="Buscar eventos..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-full px-4 py-2 pl-10 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-full text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors text-sm"
                  />
                  <svg 
                    className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-500 dark:text-gray-400" 
                    fill="none" 
                    stroke="currentColor" 
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                  {searchTerm && (
                    <button
                      onClick={() => setSearchTerm('')}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-white transition-colors"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  )}
                </div>
              </div>

              <button 
                onClick={() => {
                  if (eventScope === 'particulares') {
                    setShowCreateParticularEvent(true)
                  } else {
                    const hasRegisteredChurch = localStorage.getItem('hasRegisteredChurch')
                    if (!hasRegisteredChurch) {
                      setShowChurchRegistration(true)
                    } else {
                      console.log('Crear evento (cristianos/iglesia)')
                    }
                  }
                }}
                className="bg-primary-500 hover:bg-primary-600 text-white px-4 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-2"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                <span className="hidden sm:inline">Crear Evento</span>
              </button>
            </div>

            {/* Quick Filters */}
            <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-hide">
              <button 
                type="button"
                onClick={() => setShowFilterPanel(true)}
                className="px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-colors bg-gray-100 dark:bg-dark-hover text-black dark:text-gray-300 hover:text-black dark:hover:text-primary-400"
              >
                Filtro
              </button>
              <button 
                onClick={() => setActiveFilter('todos')}
                className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
                  activeFilter === 'todos'
                    ? 'bg-primary-500/20 dark:bg-primary-500/20 text-black dark:text-primary-400'
                    : 'bg-gray-100 dark:bg-dark-hover text-black dark:text-gray-300 hover:text-black dark:hover:text-primary-400'
                }`}
              >
                Todos
              </button>
              <button 
                onClick={() => setActiveFilter('hoy')}
                className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap flex items-center gap-2 transition-colors ${
                  activeFilter === 'hoy'
                    ? 'bg-primary-500/20 dark:bg-primary-500/20 text-black dark:text-primary-400'
                    : 'bg-gray-100 dark:bg-dark-hover text-black dark:text-gray-300 hover:text-black dark:hover:text-primary-400'
                }`}
              >
                <span className="w-2 h-2 bg-primary-500 rounded-full animate-pulse"></span> Hoy
              </button>
              <button 
                onClick={() => setActiveFilter('enVivo')}
                className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap flex items-center gap-2 transition-colors border ${
                  activeFilter === 'enVivo'
                    ? 'bg-red-600 dark:bg-red-700 border-red-500 text-white'
                    : 'bg-gray-100 dark:bg-dark-hover border-transparent text-black dark:text-gray-300 hover:bg-red-600/20 dark:hover:bg-red-600/20 hover:border-red-500/50 hover:text-white dark:hover:text-white'
                }`}
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
                </svg>
                En vivo ({allEvents.filter(e => e.isLive).length})
              </button>
              <button 
                onClick={() => setActiveFilter('proximos')}
                className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap flex items-center gap-2 transition-colors ${
                  activeFilter === 'proximos'
                    ? 'bg-primary-500/20 dark:bg-primary-500/20 text-black dark:text-primary-400'
                    : 'bg-gray-100 dark:bg-dark-hover text-black dark:text-gray-300 hover:text-black dark:hover:text-primary-400'
                }`}
              >
                <span className="w-2 h-2 bg-primary-500 rounded-full animate-pulse"></span> Próximos
              </button>
            </div>
          </div>
        </header>

        {/* Content */}
        <div className="p-4">
          {activeFilter === 'todos' ? (
            <div className="space-y-4">
              {/* Hoy Section */}
              {(
                <section>
                  <div className="flex items-center justify-between mb-4">
                    <h2 className="text-xl font-bold text-gray-900 dark:text-white flex items-center gap-2">
                      <span className="relative flex h-3 w-3">
                        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                        <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
                      </span>
                      Hoy
                    </h2>
                  </div>

                  <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-hide">
                    {filterBySearch(allEvents.filter(e => {
                      const eventDate = new Date(e.date)
                      eventDate.setHours(0, 0, 0, 0)
                      const today = new Date()
                      today.setHours(0, 0, 0, 0)
                      return eventDate.getTime() === today.getTime()
                    })).length > 0 ? (
                      filterBySearch(allEvents.filter(e => {
                        const eventDate = new Date(e.date)
                        eventDate.setHours(0, 0, 0, 0)
                        const today = new Date()
                        today.setHours(0, 0, 0, 0)
                        return eventDate.getTime() === today.getTime()
                      })).map((event) => (
                        <div key={event.id} className="bg-white dark:bg-dark-card rounded-2xl shadow-sm border border-gray-200 dark:border-dark-border overflow-hidden hover:shadow-md transition-shadow group cursor-pointer flex-shrink-0 w-80">
                          <div className="relative h-48">
                            <Image
                              src={event.image}
                              alt={event.title}
                              fill
                              className="object-cover group-hover:scale-105 transition-transform duration-500"
                            />
                            {event.isLive && (
                              <div className="absolute top-3 left-3 bg-red-600 text-white text-xs font-bold px-2 py-1 rounded flex items-center gap-1 shadow-sm">
                                <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                                  <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
                                </svg>
                                EN CURSO
                              </div>
                            )}
                          </div>
                          <div className="p-4">
                            <div className="flex items-center gap-2 mb-2">
                              <span className="text-xs font-bold text-primary-600 dark:text-primary-400 bg-primary-500/20 dark:bg-primary-500/20 px-2 py-0.5 rounded">{event.denomination}</span>
                              <span className="text-xs text-gray-700 dark:text-gray-400">• {event.category}</span>
                            </div>
                            <h3 className="font-bold text-lg text-gray-900 dark:text-white mb-1">{event.title}</h3>
                            <p className="text-sm text-gray-700 dark:text-gray-400 mb-3 flex items-center gap-1">
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                              </svg>
                              {event.location}
                            </p>
                            <button 
                              onClick={() => setSelectedEvent(event)}
                              className="w-full py-2 bg-primary-500 text-white font-medium rounded-lg hover:bg-primary-600 transition-colors"
                            >
                              Ver detalles
                            </button>
                          </div>
                        </div>
                      ))
                    ) : (
                      <div className="flex-shrink-0 w-80 flex items-center justify-center text-gray-500 dark:text-gray-400">
                        <p>No hay eventos para hoy</p>
                      </div>
                    )}
                  </div>
                </section>
              )}

              {/* Próximos Eventos Section */}
              {(
                <section>
                  <div className="flex items-center justify-between mb-4">
                    <h2 className="text-xl font-bold text-gray-900 dark:text-white">Próximos Eventos</h2>
                  </div>

                  <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-hide">
                    {filterBySearch(allEvents.filter(e => {
                      const eventDate = new Date(e.date)
                      eventDate.setHours(0, 0, 0, 0)
                      const today = new Date()
                      today.setHours(0, 0, 0, 0)
                      return eventDate.getTime() > today.getTime()
                    })).length > 0 ? (
                      filterBySearch(allEvents.filter(e => {
                        const eventDate = new Date(e.date)
                        eventDate.setHours(0, 0, 0, 0)
                        const today = new Date()
                        today.setHours(0, 0, 0, 0)
                        return eventDate.getTime() > today.getTime()
                      })).map((event) => {
                        const dateInfo = formatDate(event.date)
                        return (
                          <div key={event.id} className="bg-white dark:bg-dark-card rounded-2xl p-4 shadow-sm border border-gray-200 dark:border-dark-border flex flex-col gap-4 hover:shadow-md transition-all flex-shrink-0 w-80">
                            <div className="w-full h-32 rounded-xl overflow-hidden relative shrink-0">
                              <Image
                                src={event.image}
                                alt={event.title}
                                fill
                                className="object-cover"
                              />
                              <div className="absolute top-2 left-2 bg-white/90 backdrop-blur text-center px-2 py-1 rounded-lg shadow-sm">
                                <p className="text-xs font-bold text-red-500">{dateInfo.month}</p>
                                <p className="text-lg font-bold text-gray-800 leading-none">{dateInfo.day}</p>
                              </div>
                            </div>
                            <div className="flex-1 flex flex-col justify-between">
                              <div>
                                <div className="flex justify-between items-start">
                                  <span className={`text-xs font-bold px-2 py-0.5 rounded mb-2 inline-block ${getCategoryColor(event.category)}`}>
                                    {event.category}
                                  </span>
                                  <button className="text-gray-600 dark:text-gray-400 hover:text-primary-500 dark:hover:text-primary-400">
                                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
                                    </svg>
                                  </button>
                                </div>
                                <h3 className="font-bold text-lg text-gray-900 dark:text-white">{event.title}</h3>
                                <p className="text-sm text-gray-700 dark:text-gray-400 mt-1">{event.church} • {event.time}</p>
                                <p className="text-sm text-gray-700 dark:text-gray-400 mt-1 flex items-center gap-1">
                                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                                  </svg>
                                  {event.location}
                                </p>
                              </div>
                              <div className="flex items-center justify-between mt-4 gap-2 overflow-hidden">
                                <div className="flex items-center gap-2 flex-shrink-0">
                                  <button 
                                    onClick={() => handleAttending(event.id)}
                                    className={`px-2 py-1 text-xs font-medium rounded hover:opacity-80 transition-colors flex items-center gap-0.5 whitespace-nowrap ${
                                      attendanceCounts[event.id]?.userStatus === 'attending'
                                        ? 'text-primary-600 dark:text-primary-300 bg-primary-500/30 dark:bg-primary-500/30'
                                        : 'text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300'
                                    }`}
                                  >
                                    <span>Asistiré</span>
                                    <span className="text-gray-700 dark:text-gray-400">{attendanceCounts[event.id]?.attending || 0}</span>
                                  </button>
                                  <button 
                                    onClick={() => handleNotAttending(event.id)}
                                    className={`px-2 py-1 text-xs font-medium rounded hover:opacity-80 transition-colors whitespace-nowrap flex items-center gap-0.5 ${
                                      attendanceCounts[event.id]?.userStatus === 'notAttending'
                                        ? 'text-red-600 dark:text-red-300 bg-red-500/30 dark:bg-red-500/30'
                                        : 'text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300'
                                    }`}
                                  >
                                    <span>No asistiré</span>
                                    <span className="text-gray-700 dark:text-gray-400">{attendanceCounts[event.id]?.notAttending || 0}</span>
                                  </button>
                                </div>
                                <button 
                                  onClick={() => setSelectedEvent(event)}
                                  className="px-3 py-1.5 bg-primary-500 text-white text-sm font-medium rounded-lg hover:bg-primary-600 transition-colors whitespace-nowrap flex-shrink-0"
                                >
                                  Ver detalles
                                </button>
                              </div>
                            </div>
                          </div>
                        )
                      })
                    ) : (
                      <div className="flex-shrink-0 w-80 flex items-center justify-center text-gray-500 dark:text-gray-400">
                        <p>No hay próximos eventos</p>
                      </div>
                    )}
                  </div>
                </section>
              )}

            </div>
          ) : (
            /* Filtered Events - Vertical Scroll */
            <div className="space-y-4">
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                {activeFilter === 'hoy' && (
                  <>
                    <span className="relative flex h-3 w-3">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                      <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
                    </span>
                    Eventos de Hoy
                  </>
                )}
                {activeFilter === 'enVivo' && (
                  <>
                    <span className="relative flex h-3 w-3">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                      <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
                    </span>
                    En vivo
                  </>
                )}
                {activeFilter === 'proximos' && 'Próximos Eventos'}
              </h2>
              
              {filteredEvents.length > 0 ? (
                filteredEvents.map((event) => (
                  <div key={event.id} className="bg-white dark:bg-dark-card rounded-2xl shadow-sm border border-gray-200 dark:border-dark-border overflow-hidden hover:shadow-md transition-shadow">
                      <div className="flex flex-col sm:flex-row">
                        <div className="relative w-full sm:w-48 h-48 sm:h-auto shrink-0">
                          <Image
                            src={event.image}
                            alt={event.title}
                            fill
                            className="object-cover"
                          />
                          {event.isLive && (
                            <div className="absolute top-3 left-3 bg-red-600 text-white text-xs font-bold px-2 py-1 rounded flex items-center gap-1 shadow-sm">
                              <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                                <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
                              </svg>
                              EN CURSO
                            </div>
                          )}
                        </div>
                        <div className="flex-1 p-4 flex flex-col justify-between min-w-0">
                          <div className="min-w-0">
                            <div className="flex items-center gap-2 mb-2">
                              <span className="text-xs font-bold text-primary-600 dark:text-primary-400 bg-primary-500/20 dark:bg-primary-500/20 px-2 py-0.5 rounded flex-shrink-0">{event.denomination}</span>
                              <span className="text-xs text-gray-600 dark:text-gray-400 truncate">• {event.category}</span>
                            </div>
                            <h3 className="font-bold text-lg text-gray-900 dark:text-white mb-2 break-words">{event.title}</h3>
                          <div className="space-y-1 mb-3">
                            <p className="text-sm text-gray-700 dark:text-gray-400 flex items-center gap-1 min-w-0">
                              <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                              </svg>
                              <span className="truncate">{event.church} • {event.time}</span>
                            </p>
                            <p className="text-sm text-gray-700 dark:text-gray-400 flex items-center gap-1 min-w-0">
                              <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                              </svg>
                              <span className="truncate">{event.location}</span>
                            </p>
                          </div>
                        </div>
                          <div className="flex flex-col gap-3">
                            <div className="flex items-center gap-2">
                              <button 
                                onClick={() => handleAttending(event.id)}
                                className={`px-2 py-1 text-xs font-medium rounded hover:opacity-80 transition-colors flex items-center gap-0.5 whitespace-nowrap ${
                                  attendanceCounts[event.id]?.userStatus === 'attending'
                                    ? 'text-primary-600 dark:text-primary-300 bg-primary-500/30 dark:bg-primary-500/30'
                                    : 'text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300'
                                }`}
                              >
                                <span>Asistiré</span>
                                <span className="text-gray-700 dark:text-gray-400">{attendanceCounts[event.id]?.attending || 0}</span>
                              </button>
                              <button 
                                onClick={() => handleNotAttending(event.id)}
                                className={`px-2 py-1 text-xs font-medium rounded hover:opacity-80 transition-colors whitespace-nowrap flex items-center gap-0.5 ${
                                  attendanceCounts[event.id]?.userStatus === 'notAttending'
                                    ? 'text-red-600 dark:text-red-300 bg-red-500/30 dark:bg-red-500/30'
                                    : 'text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300'
                                }`}
                              >
                                <span>No asistiré</span>
                                <span className="text-gray-700 dark:text-gray-400">{attendanceCounts[event.id]?.notAttending || 0}</span>
                              </button>
                            </div>
                            <button 
                              onClick={() => setSelectedEvent(event)}
                              className="w-full sm:w-auto sm:px-6 py-2 bg-primary-500 text-white font-medium rounded-lg hover:bg-primary-600 transition-colors"
                            >
                              Ver detalles
                            </button>
                          </div>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-12 text-gray-400">
                  <p>No hay eventos disponibles</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Bottom Navigation */}
      <BottomNavigation />

      {/* Panel de Filtros */}
      {showFilterPanel && (
        <div
          className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-2"
          onClick={() => setShowFilterPanel(false)}
        >
          <div
            className="bg-dark-card rounded-2xl max-w-md w-full h-[96vh] max-h-[96vh] border border-dark-border shadow-2xl flex flex-col overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between p-4 border-b border-dark-border flex-shrink-0">
              <h2 className="text-xl font-bold text-white">Filtros</h2>
              <button
                onClick={() => setShowFilterPanel(false)}
                className="w-8 h-8 bg-dark-hover rounded-full flex items-center justify-center text-gray-400 hover:text-white transition-colors"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Contenido scrolleable */}
            <div className="flex-1 overflow-y-auto p-4 space-y-6">
              {/* Categorías (Populares) */}
              <section>
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-bold text-white">Categorías</h3>
                  <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
                  </svg>
                </div>
                <p className="text-sm text-gray-400 mb-3">Selecciona una o más</p>
                <div className="space-y-2">
                  {[
                    { name: 'Educación y Capacitación', color: 'bg-cyan-500', selected: false },
                    { name: 'Conferencias y Charlas', color: 'bg-red-500', selected: false },
                    { name: 'Deportes y Actividad Física', color: 'bg-green-500', selected: false },
                    { name: 'Arte y Cultura', color: 'bg-amber-500', selected: false },
                    { name: 'Social y Familiar', color: 'bg-purple-500', selected: false },
                    { name: 'Salud y Bienestar', color: 'bg-emerald-500', selected: false },
                    { name: 'Servicio y Acción Social', color: 'bg-pink-500', selected: false },
                    { name: 'Gestión y Planeación', color: 'bg-indigo-500', selected: false },
                  ].map((item) => (
                    <button
                      key={item.name}
                      type="button"
                      className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                        item.selected
                          ? 'bg-cyan-500/20 border border-cyan-500/50 text-white'
                          : 'bg-dark-hover border border-transparent text-gray-300 hover:text-white'
                      }`}
                    >
                      <span className={`w-3 h-3 rounded-full flex-shrink-0 ${item.color}`} />
                      <span className="font-medium">{item.name}</span>
                    </button>
                  ))}
                </div>
              </section>

              {/* Tipo de evento */}
              <section>
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-bold text-white">Tipo de evento</h3>
                  <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
                  </svg>
                </div>
                <p className="text-sm text-gray-400 mb-3">Todos</p>
                <div className="flex flex-wrap gap-2">
                  {['Cultos', 'Estudios Bíblicos', 'Conferencias', 'Retiros', 'Alabanza', 'Bautismos'].map((tipo) => (
                    <button
                      key={tipo}
                      type="button"
                      className="px-4 py-2 rounded-full text-sm font-medium bg-dark-hover text-gray-300 hover:text-white hover:bg-dark-border transition-colors"
                    >
                      {tipo}
                    </button>
                  ))}
                </div>
              </section>

              {/* Distancia máxima */}
              <section>
                <h3 className="font-bold text-white mb-3">Distancia máxima</h3>
                <div className="space-y-2">
                  <input
                    type="range"
                    min="1"
                    max="100"
                    defaultValue="50"
                    className="w-full h-2 bg-dark-hover rounded-lg appearance-none cursor-pointer accent-cyan-500"
                  />
                  <div className="flex justify-between text-sm text-gray-400">
                    <span>1 km</span>
                    <span className="text-cyan-400 font-semibold">50 km</span>
                    <span>100 km</span>
                  </div>
                </div>
              </section>

              {/* Costo */}
              <section>
                <h3 className="font-bold text-white mb-3">Costo</h3>
                <div className="flex gap-2">
                  <button
                    type="button"
                    className="flex-1 px-4 py-2.5 rounded-lg text-sm font-medium bg-cyan-500 text-white"
                  >
                    Todos
                  </button>
                  <button
                    type="button"
                    className="flex-1 px-4 py-2.5 rounded-lg text-sm font-medium bg-dark-hover text-white hover:bg-dark-border"
                  >
                    Gratis
                  </button>
                  <button
                    type="button"
                    className="flex-1 px-4 py-2.5 rounded-lg text-sm font-medium bg-dark-hover text-white hover:bg-dark-border"
                  >
                    De pago
                  </button>
                </div>
              </section>

              {/* Cuándo */}
              <section>
                <h3 className="font-bold text-white mb-3">Cuándo</h3>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    className="px-4 py-2.5 rounded-lg text-sm font-medium bg-cyan-500 text-white"
                  >
                    Todos
                  </button>
                  <button
                    type="button"
                    className="px-4 py-2.5 rounded-lg text-sm font-medium bg-dark-hover text-white hover:bg-dark-border"
                  >
                    Hoy
                  </button>
                  <button
                    type="button"
                    className="px-4 py-2.5 rounded-lg text-sm font-medium bg-dark-hover text-white hover:bg-dark-border"
                  >
                    Esta semana
                  </button>
                  <button
                    type="button"
                    className="px-4 py-2.5 rounded-lg text-sm font-medium bg-dark-hover text-white hover:bg-dark-border"
                  >
                    Este mes
                  </button>
                </div>
              </section>
            </div>
          </div>
        </div>
      )}

      {/* Event Details Modal */}
      {selectedEvent && (
        <div 
          className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          onClick={() => setSelectedEvent(null)}
        >
          <div 
            className="bg-white dark:bg-dark-card rounded-2xl max-w-md w-full border border-gray-200 dark:border-dark-border shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Image */}
            <div className="relative h-48">
              <Image
                src={selectedEvent.image}
                alt={selectedEvent.title}
                fill
                className="object-cover rounded-t-2xl"
              />
              {selectedEvent.isLive && (
                <div className="absolute top-3 left-3 bg-red-600 text-white text-xs font-bold px-2 py-1 rounded flex items-center gap-1 shadow-sm">
                  <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
                  </svg>
                  EN CURSO
                </div>
              )}
              <button
                onClick={() => setSelectedEvent(null)}
                className="absolute top-3 right-3 w-8 h-8 bg-black/60 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-black/80 transition-colors"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Content */}
            <div className="p-6">
              <div className="flex items-center gap-2 mb-3">
                <span className="text-xs font-bold text-primary-400 bg-primary-500/20 px-2 py-0.5 rounded">
                  {selectedEvent.denomination}
                </span>
                <span className="text-xs text-gray-600 dark:text-gray-400">• {selectedEvent.category}</span>
              </div>

              <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-3">{selectedEvent.title}</h2>

              <div className="space-y-2 mb-4">
                <div className="flex items-center gap-2 text-gray-700 dark:text-gray-300">
                  <svg className="w-5 h-5 text-gray-600 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span className="text-sm">{selectedEvent.time}</span>
                </div>

                <div className="flex items-center gap-2 text-gray-700 dark:text-gray-300">
                  <svg className="w-5 h-5 text-gray-600 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <span className="text-sm">{selectedEvent.location}</span>
                </div>

                <div className="flex items-center gap-2 text-gray-700 dark:text-gray-300">
                  <svg className="w-5 h-5 text-gray-600 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                  <span className="text-sm">{selectedEvent.church}</span>
                </div>
              </div>

              {/* Description */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">Descripción</h3>
                <p className="text-gray-700 dark:text-gray-300 text-sm leading-relaxed">
                  {selectedEvent.description}
                </p>
              </div>

              {/* Actions */}
              <div className="flex gap-3">
                <button className="flex-1 py-3 px-4 bg-primary-500 hover:bg-primary-600 text-white font-medium rounded-lg transition-colors">
                  Asistiré
                </button>
                <button className="flex-1 py-3 px-4 bg-gray-100 dark:bg-dark-hover hover:bg-gray-200 dark:hover:bg-dark-border text-gray-900 dark:text-gray-300 font-medium rounded-lg transition-colors">
                  Me interesa
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modal de Registro de Iglesia */}
      {showChurchRegistration && (
        <div
          className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          onClick={() => setShowChurchRegistration(false)}
        >
          <div
            className="bg-white dark:bg-dark-card rounded-2xl max-w-md w-full border border-gray-200 dark:border-dark-border shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Registrar mi iglesia</h2>
                <button
                  onClick={() => setShowChurchRegistration(false)}
                  className="w-8 h-8 bg-gray-100 dark:bg-dark-hover rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  // Guardar en localStorage que ya registró su iglesia
                  localStorage.setItem('hasRegisteredChurch', 'true')
                  // Aquí iría la lógica para guardar los datos de la iglesia
                  console.log('Datos de la iglesia:', churchFormData)
                  setShowChurchRegistration(false)
                  // Resetear el formulario
                  setChurchFormData({ name: '', denomination: '', city: '', password: '' })
                }}
                className="space-y-4"
              >
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Nombre de la iglesia
                  </label>
                  <input
                    type="text"
                    value={churchFormData.name}
                    onChange={(e) => setChurchFormData({ ...churchFormData, name: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors"
                    placeholder="Ingresa el nombre de tu iglesia"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Denominación
                  </label>
                  <select
                    value={churchFormData.denomination}
                    onChange={(e) => setChurchFormData({ ...churchFormData, denomination: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white focus:outline-none focus:border-primary-500 transition-colors"
                    required
                  >
                    <option value="">Selecciona una denominación</option>
                    {Object.entries(denominationNames).map(([key, name]) => (
                      <option key={key} value={key} className="bg-white dark:bg-dark-card">
                        {name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Ciudad
                  </label>
                  <input
                    type="text"
                    value={churchFormData.city}
                    onChange={(e) => setChurchFormData({ ...churchFormData, city: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors"
                    placeholder="Ingresa la ciudad"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Crear contraseña
                  </label>
                  <input
                    type="password"
                    value={churchFormData.password}
                    onChange={(e) => setChurchFormData({ ...churchFormData, password: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors"
                    placeholder="Crea una contraseña"
                    required
                    minLength={6}
                  />
                </div>

                <div className="flex gap-3 pt-4">
                  <button
                    type="button"
                    onClick={() => setShowChurchRegistration(false)}
                    className="flex-1 py-3 px-4 bg-gray-100 dark:bg-dark-hover hover:bg-gray-200 dark:hover:bg-dark-border text-gray-900 dark:text-gray-300 font-medium rounded-lg transition-colors"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-3 px-4 bg-primary-500 hover:bg-primary-600 text-white font-medium rounded-lg transition-colors"
                  >
                    Registrar
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Modal Crear evento (Particulares) - con categoría */}
      {showCreateParticularEvent && (
        <div
          className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          onClick={() => setShowCreateParticularEvent(false)}
        >
          <div
            className="bg-white dark:bg-dark-card rounded-2xl max-w-md w-full border border-gray-200 dark:border-dark-border shadow-2xl max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Crear evento</h2>
                <button
                  onClick={() => setShowCreateParticularEvent(false)}
                  className="w-8 h-8 bg-gray-100 dark:bg-dark-hover rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  console.log('Evento particular:', particularEventForm)
                  setShowCreateParticularEvent(false)
                  setParticularEventForm({ title: '', category: '', location: '', date: '', description: '' })
                }}
                className="space-y-4"
              >
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Título del evento
                  </label>
                  <input
                    type="text"
                    value={particularEventForm.title}
                    onChange={(e) => setParticularEventForm({ ...particularEventForm, title: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors"
                    placeholder="Ej. Taller de oración"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Categoría
                  </label>
                  <select
                    value={particularEventForm.category}
                    onChange={(e) => setParticularEventForm({ ...particularEventForm, category: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white focus:outline-none focus:border-primary-500 transition-colors"
                    required
                  >
                    <option value="">Selecciona una categoría</option>
                    {EVENT_CATEGORIES.map((cat) => (
                      <option key={cat} value={cat} className="bg-white dark:bg-dark-card">
                        {cat}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Lugar o dirección
                  </label>
                  <input
                    type="text"
                    value={particularEventForm.location}
                    onChange={(e) => setParticularEventForm({ ...particularEventForm, location: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors"
                    placeholder="Ej. Parque central, sala comunal"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Fecha
                  </label>
                  <input
                    type="date"
                    value={particularEventForm.date}
                    onChange={(e) => setParticularEventForm({ ...particularEventForm, date: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white focus:outline-none focus:border-primary-500 transition-colors"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Descripción (opcional)
                  </label>
                  <textarea
                    value={particularEventForm.description}
                    onChange={(e) => setParticularEventForm({ ...particularEventForm, description: e.target.value })}
                    className="w-full px-4 py-2 bg-gray-100 dark:bg-dark-hover border border-gray-200 dark:border-dark-border rounded-lg text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors resize-none"
                    placeholder="Breve descripción del evento"
                    rows={3}
                  />
                </div>

                <div className="flex gap-3 pt-4">
                  <button
                    type="button"
                    onClick={() => setShowCreateParticularEvent(false)}
                    className="flex-1 py-3 px-4 bg-gray-100 dark:bg-dark-hover hover:bg-gray-200 dark:hover:bg-dark-border text-gray-900 dark:text-gray-300 font-medium rounded-lg transition-colors"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-3 px-4 bg-primary-500 hover:bg-primary-600 text-white font-medium rounded-lg transition-colors"
                  >
                    Crear evento
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
