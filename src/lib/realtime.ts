import { RealtimeClient } from '@supabase/realtime-js'
import { supabase } from './supabase'

export function subscribeToMessages(
  userId: string,
  otherUserId: string,
  callback: (message: any) => void
) {
  // Crear canal único para la conversación
  const channelName = [userId, otherUserId].sort().join('-')
  
  const channel = supabase
    .channel(`messages:${channelName}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `sender_id=eq.${otherUserId}`,
      },
      (payload) => {
        callback(payload.new)
      }
    )
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}











