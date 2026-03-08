'use client'

import { useRouter } from 'next/navigation'
import { useState } from 'react'
import { useTheme } from '@/contexts/ThemeContext'
import { signOut } from 'next-auth/react'
import { BottomNavigation } from '@/components/templates/BottomNavigation'

export default function SettingsPage() {
  const router = useRouter()
  const { theme, setTheme } = useTheme()
  const [showThemeModal, setShowThemeModal] = useState(false)

  const handleSignOut = async () => {
    await signOut({ callbackUrl: '/auth/signin' })
  }

  const handleThemeSelect = (selectedTheme: 'light' | 'dark') => {
    setTheme(selectedTheme)
    setShowThemeModal(false)
  }

  return (
    <div className="min-h-screen bg-white dark:bg-dark-bg pb-24">
      <div className="max-w-md mx-auto">
        {/* Header */}
        <header className="flex items-center justify-between px-4 py-3 bg-white dark:bg-dark-bg border-b border-gray-200 dark:border-dark-border sticky top-0 z-20">
          <button
            onClick={() => router.back()}
            className="w-10 h-10 flex items-center justify-center text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-dark-hover rounded-full transition-colors"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 className="text-lg font-semibold text-gray-900 dark:text-white">Ajustes</h1>
          <div className="w-10" /> {/* Spacer para centrar el título */}
        </header>

        {/* Settings Content */}
        <div className="px-4 py-6">
          {/* Theme Section */}
          <div className="mb-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Apariencia</h2>
            
            {/* Theme Toggle */}
            <button
              onClick={() => setShowThemeModal(true)}
              className="w-full px-4 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors"
            >
              <div className="text-left">
                <p className="text-gray-900 dark:text-white font-medium">
                  {theme === 'dark' ? 'Modo Oscuro' : 'Modo Claro'}
                </p>
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  {theme === 'dark' ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
                </p>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          {/* General Section */}
          <div className="mb-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">General</h2>
            
            {/* Notifications */}
            <button className="w-full px-4 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors">
              <div className="text-left">
                <p className="text-gray-900 dark:text-white font-medium">Notificaciones</p>
                <p className="text-sm text-gray-500 dark:text-gray-400">Gestionar notificaciones</p>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>

            {/* Privacy */}
            <button className="w-full px-4 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors">
              <div className="text-left">
                <p className="text-gray-900 dark:text-white font-medium">Privacidad</p>
                <p className="text-sm text-gray-500 dark:text-gray-400">Configurar privacidad</p>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>

            {/* Account */}
            <button className="w-full px-4 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors">
              <div className="text-left">
                <p className="text-gray-900 dark:text-white font-medium">Cuenta</p>
                <p className="text-sm text-gray-500 dark:text-gray-400">Gestionar cuenta</p>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          {/* About Section */}
          <div className="mb-6">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Acerca de</h2>
            
            <button className="w-full px-4 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors">
              <div className="text-left">
                <p className="text-gray-900 dark:text-white font-medium">Información</p>
                <p className="text-sm text-gray-500 dark:text-gray-400">Versión y más información</p>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          {/* Sign Out Section */}
          <div className="mb-6">
            <button
              onClick={handleSignOut}
              className="w-full px-4 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors"
            >
              <p className="text-red-600 dark:text-red-400 font-medium">Cerrar Sesión</p>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      {/* Bottom Navigation */}
      <BottomNavigation />

      {/* Theme Selection Modal */}
      {showThemeModal && (
        <>
          {/* Overlay */}
          <div
            className="fixed inset-0 bg-black/50 z-40"
            onClick={() => setShowThemeModal(false)}
          />
          
          {/* Modal */}
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
            <div className="bg-white dark:bg-dark-card rounded-2xl shadow-2xl max-w-sm w-full pointer-events-auto overflow-hidden">
              {/* Modo Claro */}
              <button
                onClick={() => handleThemeSelect('light')}
                className="w-full px-6 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors border-b border-gray-200 dark:border-dark-border"
              >
                <p className="text-gray-900 dark:text-white font-medium">Modo Claro</p>
                {theme === 'light' && (
                  <svg className="w-5 h-5 text-primary-600 dark:text-primary-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                )}
              </button>
              
              {/* Modo Oscuro */}
              <button
                onClick={() => handleThemeSelect('dark')}
                className="w-full px-6 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-dark-hover transition-colors"
              >
                <p className="text-gray-900 dark:text-white font-medium">Modo Oscuro</p>
                {theme === 'dark' && (
                  <svg className="w-5 h-5 text-primary-600 dark:text-primary-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                )}
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
