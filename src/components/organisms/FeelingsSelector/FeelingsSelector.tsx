'use client'

import { memo, useState, useEffect } from 'react'

interface FeelingsSelectorProps {
  selectedFeeling: string
  onFeelingChange: (feeling: string) => void
}

const feelings = [
  {
    id: 'bendecido',
    label: 'Bendecido',
    icon: '❤️',
    emoji: '❤️',
  },
  {
    id: 'agradecido',
    label: 'Agradecido',
    icon: '🙌',
    emoji: '🙌',
  },
  {
    id: 'feliz',
    label: 'Feliz',
    icon: '😄',
    emoji: '😄',
  },
  {
    id: 'fortalecido',
    label: 'Fortalecido',
    icon: '💎',
    emoji: '💎',
  },
  {
    id: 'inspirado',
    label: 'Inspirado',
    icon: '🌟',
    emoji: '🌟',
  },
  {
    id: 'en-paz',
    label: 'En paz',
    icon: '🤗',
    emoji: '🤗',
  },
]

const feelingLabels: Record<string, string> = {
  bendecido: 'bendecido',
  agradecido: 'agradecido',
  feliz: 'feliz',
  fortalecido: 'fortalecido',
  inspirado: 'inspirado',
  'en-paz': 'en paz',
}

function FeelingsSelectorComponent({ selectedFeeling, onFeelingChange }: FeelingsSelectorProps) {
  const [isChanging, setIsChanging] = useState(false)
  const [canChangeToday, setCanChangeToday] = useState(true)
  
  const hasSelected = selectedFeeling && selectedFeeling !== ''

  // Verificar si se puede cambiar el estado hoy
  useEffect(() => {
    const checkCanChangeToday = () => {
      const lastChangeDate = localStorage.getItem('lastMoodChangeDate')
      const today = new Date().toDateString()
      
      // Si no hay fecha guardada o es un nuevo día, se puede cambiar
      if (!lastChangeDate || lastChangeDate !== today) {
        setCanChangeToday(true)
        if (lastChangeDate && lastChangeDate !== today) {
          localStorage.removeItem('lastMoodChangeDate')
        }
      } else {
        setCanChangeToday(false)
      }
    }

    checkCanChangeToday()
    // Verificar cada minuto para detectar cuando pasa la medianoche
    const interval = setInterval(checkCanChangeToday, 60000)
    
    return () => clearInterval(interval)
  }, [])

  const handleChangeMood = () => {
    if (canChangeToday) {
      setIsChanging(true)
    }
  }

  const handleCancel = () => {
    setIsChanging(false)
  }

  const handleSelectFeeling = (feelingId: string) => {
    onFeelingChange(feelingId)
    setIsChanging(false)
    // Marcar que se cambió el estado de ánimo hoy
    if (canChangeToday) {
      const today = new Date().toDateString()
      localStorage.setItem('lastMoodChangeDate', today)
      setCanChangeToday(false)
    }
  }

  const showGrid = !hasSelected || isChanging

  return (
    <div className="mb-0">
      {/* Feelings Card */}
      <div className="bg-white dark:bg-dark-card rounded-2xl p-2 mb-4">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2 flex-1 justify-center">
            {hasSelected ? (
              <>
                <span className="text-2xl">{feelings.find(f => f.id === selectedFeeling)?.emoji}</span>
                <h3 className="text-gray-900 dark:text-white font-semibold capitalize">
                  {feelings.find(f => f.id === selectedFeeling)?.label}
                </h3>
              </>
            ) : (
              <h3 className="text-gray-900 dark:text-white font-semibold capitalize">
                ¿Cómo te sientes hoy?
              </h3>
            )}
          </div>
          {hasSelected && !isChanging && (
            <button
              onClick={handleChangeMood}
              className={`text-xs font-medium transition-colors ${
                canChangeToday
                  ? 'text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300 cursor-pointer'
                  : 'text-gray-400 dark:text-gray-500 cursor-not-allowed opacity-50'
              }`}
              disabled={!canChangeToday}
              title={!canChangeToday ? 'Ya cambiaste tu estado de ánimo hoy. Podrás cambiarlo mañana.' : 'Cambiar estado de ánimo'}
            >
              Cambiar estado de ánimo
            </button>
          )}
        </div>

        {/* Feelings Buttons Grid */}
        {showGrid && (
          <>
            <div className="grid grid-cols-3 gap-1.5 mb-1">
              {feelings.map((feeling) => {
                const isSelected = selectedFeeling === feeling.id
                return (
                  <button
                    key={feeling.id}
                    onClick={() => handleSelectFeeling(feeling.id)}
                    className={`
                      flex flex-col items-center justify-center gap-1 p-2 rounded-xl transition-all
                      ${
                        isSelected
                          ? 'text-primary-600 dark:text-primary-400 font-bold'
                          : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
                      }
                    `}
                  >
                    <span className="text-2xl">{feeling.icon}</span>
                    <span className="text-xs font-medium">{feeling.label}</span>
                  </button>
                )
              })}
            </div>
            {isChanging && (
              <div className="flex justify-center">
                <button
                  onClick={handleCancel}
                  className="text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white font-medium transition-colors"
                >
                  Cancelar
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}

export const FeelingsSelector = memo(FeelingsSelectorComponent)

