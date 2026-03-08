export interface PostFormProps {
  onSubmit: (data: { content: string; file?: File }) => Promise<void>
  userImage?: string | null
  userName?: string | null
}

export interface PostFormData {
  content: string
  file?: File
}











