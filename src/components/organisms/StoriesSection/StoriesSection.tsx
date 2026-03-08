'use client'

import { memo, useState } from 'react'
import { useSession } from 'next-auth/react'
import { StoryViewer } from '../StoryViewer'

interface Story {
  id: string
  image?: string
  video?: string
  type: 'image' | 'video'
  views: number
  likes: number
  viewed?: boolean
  author: {
    id: string
    name: string
    username: string
    avatar?: string
  }
}

interface StoriesSectionProps {
  stories?: Story[]
}

function StoriesSectionComponent({ stories = [] }: StoriesSectionProps) {
  const { data: session } = useSession()
  const currentUserId = session?.user?.id
  const [selectedStory, setSelectedStory] = useState<Story | null>(null)
  const [viewedStories, setViewedStories] = useState<Set<string>>(new Set())
  
  // Datos de ejemplo con imágenes y videos de amigos/seguidos
  const mockStories: Story[] = [
    {
      id: '1',
      image: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=600&fit=crop',
      type: 'image',
      views: 123,
      likes: 45,
      viewed: false, // No vista
      author: {
        id: '1',
        name: 'María González',
        username: '@maria_gonzalez',
        avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop',
      },
    },
    {
      id: '2',
      video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      type: 'video',
      views: 89,
      likes: 32,
      viewed: true, // Ya vista
      author: {
        id: '2',
        name: 'Juan Pérez',
        username: '@juan_perez',
        avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop',
      },
    },
    {
      id: '3',
      video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      type: 'video',
      views: 256,
      likes: 78,
      viewed: false, // No vista
      author: {
        id: '3',
        name: 'Ana Martínez',
        username: '@ana_martinez',
        avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop',
      },
    },
    {
      id: '4',
      video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      type: 'video',
      views: 145,
      likes: 56,
      viewed: true, // Ya vista
      author: {
        id: '4',
        name: 'Carlos López',
        username: '@carlos_lopez',
        avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop',
      },
    },
    {
      id: '5',
      image: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=400&h=600&fit=crop',
      type: 'image',
      views: 201,
      likes: 92,
      viewed: false, // No vista
      author: {
        id: '5',
        name: 'Laura Sánchez',
        username: '@laura_sanchez',
        avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop',
      },
    },
    {
      id: '6',
      video: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      type: 'video',
      views: 167,
      likes: 64,
      viewed: true, // Ya vista
      author: {
        id: '6',
        name: 'Pedro Ramírez',
        username: '@pedro_ramirez',
        avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop',
      },
    },
  ]

  const displayStories = stories.length > 0 ? stories : mockStories
  
  // Marcar historias como vistas si están en el set
  const storiesWithViewStatus = displayStories.map(story => ({
    ...story,
    viewed: story.viewed || viewedStories.has(story.id)
  }))
  
  // Ordenar historias: no vistas primero, vistas después
  const sortedStories = [...storiesWithViewStatus].sort((a, b) => {
    // Si a no está vista y b sí, a va primero
    if (!a.viewed && b.viewed) return -1
    // Si a está vista y b no, b va primero
    if (a.viewed && !b.viewed) return 1
    // Si ambas tienen el mismo estado, mantener orden original
    return 0
  })

  const handleStoryClick = (story: Story) => {
    setSelectedStory(story)
  }

  const handleCloseStory = () => {
    setSelectedStory(null)
  }

  const handleMarkAsViewed = (storyId: string) => {
    // Marcar la historia como vista
    setViewedStories(prev => new Set(prev).add(storyId))
  }

  return (
    <div className="mb-0 pt-2 bg-white dark:bg-dark-bg">
      {/* Stories Container */}
      <div className="flex gap-0.5 pl-1 pr-4 overflow-x-auto scrollbar-hide pb-2">
        {/* New Story Card - Always first */}
        <div className="flex-shrink-0 w-28 h-[152px] rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600 bg-white dark:bg-dark-card flex flex-col items-center justify-center gap-1.5 cursor-pointer hover:border-primary-500 dark:hover:border-primary-500 hover:bg-gray-50 dark:hover:bg-dark-hover transition-all relative z-10">
          <div className="w-8 h-8 rounded-full bg-primary-600 flex items-center justify-center shadow-lg">
            <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 4v16m8-8H4"
              />
            </svg>
          </div>
          <span className="text-gray-900 dark:text-white text-xs font-semibold">Nuevo</span>
        </div>

        {/* Existing Stories */}
        {sortedStories.map((story) => (
          <div
            key={story.id}
            onClick={() => handleStoryClick(story)}
            className="flex-shrink-0 w-28 h-[152px] rounded-lg overflow-hidden cursor-pointer group relative"
          >
            {/* Media Content - Full Height */}
            {story.type === 'image' && story.image ? (
              <img
                src={story.image}
                alt="Story"
                className={`w-full h-full object-cover transition-transform duration-300 group-hover:scale-105 ${
                  !story.viewed ? 'blur-[2px]' : ''
                }`}
              />
            ) : story.type === 'video' && story.video ? (
              <video
                src={story.video}
                className={`w-full h-full object-cover transition-transform duration-300 group-hover:scale-105 ${
                  !story.viewed ? 'blur-[2px]' : ''
                }`}
                muted
                playsInline
                loop
              />
            ) : (
              <div className="w-full h-full bg-gray-300 dark:bg-dark-hover"></div>
            )}
            
            {/* Subtle Overlay for better text readability */}
            <div className="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/40"></div>
            
            {/* Avatar Circle - Center (Friend/Following Avatar) */}
            {story.author.avatar ? (
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-14 h-14 rounded-full shadow-md z-10 overflow-hidden">
                {!story.viewed ? (
                  <div className="w-full h-full rounded-full p-[5px] bg-gradient-to-r from-primary-500 to-pink-500">
                    <div className="w-full h-full rounded-full overflow-hidden">
                      <img 
                        src={story.author.avatar} 
                        alt={story.author.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                  </div>
                ) : (
                  <div className="w-full h-full rounded-full border-[5px] border-gray-300 dark:border-gray-600">
                    <img 
                      src={story.author.avatar} 
                      alt={story.author.name}
                      className="w-full h-full object-cover"
                    />
                  </div>
                )}
              </div>
            ) : (
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-14 h-14 rounded-full shadow-md z-10">
                {!story.viewed ? (
                  <div className="w-full h-full rounded-full p-[5px] bg-gradient-to-r from-primary-500 to-pink-500">
                    <div className="w-full h-full rounded-full bg-gray-400 dark:bg-gray-500 flex items-center justify-center text-white text-sm font-bold">
                      {story.author.name.charAt(0).toUpperCase()}
                    </div>
                  </div>
                ) : (
                  <div className="w-full h-full rounded-full bg-gray-400 dark:bg-gray-500 border-[5px] border-gray-300 dark:border-gray-600 flex items-center justify-center text-white text-sm font-bold">
                    {story.author.name.charAt(0).toUpperCase()}
                  </div>
                )}
              </div>
            )}
            
            {/* Stats Overlay - Bottom - Solo visible para el dueño de la historia */}
            {currentUserId === story.author.id && (
              <div className="absolute bottom-0 left-0 right-0 p-1.5">
                <div className="flex items-center justify-between text-white">
                  <div className="flex items-center gap-0.5 bg-black/30 backdrop-blur-sm rounded-full px-1.5 py-0.5">
                    <svg className="w-2.5 h-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                      />
                    </svg>
                    <span className="text-xs font-semibold">{story.views}</span>
                  </div>
                  <div className="flex items-center gap-0.5 bg-black/30 backdrop-blur-sm rounded-full px-1.5 py-0.5">
                    <svg className="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
                    </svg>
                    <span className="text-xs font-semibold">{story.likes}</span>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Story Viewer Modal */}
      <StoryViewer 
        story={selectedStory} 
        onClose={handleCloseStory}
        onMarkAsViewed={handleMarkAsViewed}
      />
    </div>
  )
}

export const StoriesSection = memo(StoriesSectionComponent)

