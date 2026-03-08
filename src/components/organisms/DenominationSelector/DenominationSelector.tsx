'use client'

import { useState } from 'react'

interface DenominationSelectorProps {
  onSelect: (denomination: string) => void
}

const denominations = [
  { id: 'bautista', name: 'Bautista', color: 'bg-primary-500' },
  { id: 'pentecostal', name: 'Pentecostal', color: 'bg-red-500' },
  { id: 'presbiteriano', name: 'Presbiteriano', color: 'bg-green-500' },
  { id: 'metodista', name: 'Metodista', color: 'bg-blue-500' },
  { id: 'luterano', name: 'Luterano', color: 'bg-purple-500' },
  { id: 'anglicano', name: 'Anglicano', color: 'bg-yellow-500' },
  { id: 'catolico', name: 'Católico', color: 'bg-indigo-500' },
  { id: 'otra', name: 'Otra', color: 'bg-gray-500' },
]

export function DenominationSelector({ onSelect }: DenominationSelectorProps) {
  const [selectedDenomination, setSelectedDenomination] = useState<string | null>(null)
  const [showConfirmation, setShowConfirmation] = useState(false)

  const handleSelect = (denomination: string) => {
    setSelectedDenomination(denomination)
    setShowConfirmation(true)
  }

  const handleConfirm = () => {
    if (selectedDenomination) {
      onSelect(selectedDenomination)
    }
  }

  const handleCancel = () => {
    setShowConfirmation(false)
    setSelectedDenomination(null)
  }

  if (showConfirmation) {
    const denomination = denominations.find(d => d.id === selectedDenomination)
    return (
      <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
        <div className="bg-dark-card rounded-2xl p-6 max-w-md w-full border border-dark-border shadow-2xl">
          <div className="text-center mb-6">
            <div className="w-16 h-16 bg-yellow-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <h2 className="text-2xl font-bold text-white mb-2">¿Estás seguro?</h2>
            <p className="text-gray-400 text-sm">
              Has seleccionado: <span className="font-bold text-white">{denomination?.name}</span>
            </p>
          </div>

          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 mb-6">
            <div className="flex items-start gap-3">
              <svg className="w-5 h-5 text-yellow-400 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
              <div>
                <p className="text-yellow-400 font-semibold text-sm mb-1">Importante</p>
                <p className="text-gray-300 text-sm leading-relaxed">
                  Una vez que confirmes tu denominación, <strong className="text-white">no podrás cambiarla</strong> hasta que hagas una petición válida explicando el motivo del cambio. Esta decisión ayuda a mantener la integridad de nuestra comunidad.
                </p>
              </div>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={handleCancel}
              className="flex-1 py-3 px-4 bg-dark-hover hover:bg-dark-border text-gray-300 font-medium rounded-lg transition-colors"
            >
              Cancelar
            </button>
            <button
              onClick={handleConfirm}
              className="flex-1 py-3 px-4 bg-primary-500 hover:bg-primary-600 text-white font-medium rounded-lg transition-colors"
            >
              Confirmar
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-dark-card rounded-2xl p-6 max-w-md w-full border border-dark-border shadow-2xl">
        <div className="text-center mb-6">
          <div className="w-16 h-16 bg-primary-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">¿Cuál es tu denominación?</h2>
          <p className="text-gray-400 text-sm">
            Selecciona tu denominación para ver eventos relevantes a tu fe
          </p>
        </div>

        <div className="space-y-2 mb-6 max-h-96 overflow-y-auto">
          {denominations.map((denomination) => (
            <button
              key={denomination.id}
              onClick={() => handleSelect(denomination.id)}
              className="w-full flex items-center gap-4 p-4 bg-dark-hover hover:bg-dark-border rounded-xl transition-all group border border-transparent hover:border-primary-500/30"
            >
              <div className={`w-3 h-3 rounded-full ${denomination.color} group-hover:scale-125 transition-transform`}></div>
              <span className="flex-1 text-left text-white font-medium">{denomination.name}</span>
              <svg className="w-5 h-5 text-gray-400 group-hover:text-primary-400 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          ))}
        </div>

        <p className="text-xs text-gray-500 text-center">
          Esta información nos ayuda a mostrarte eventos relevantes
        </p>
      </div>
    </div>
  )
}









