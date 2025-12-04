---
name: frontend
description: Guidance for frontend development with React 19, Vite, Tailwind CSS v4, shadcn/ui, and React Router. Use when adding pages, components, forms, or styling.
---

# Frontend Development Skill

This skill provides guidance for making changes to the frontend package built with Vite, React 19, Tailwind CSS v4, and shadcn/ui.

## Project Structure

```
packages/frontend/src/
├── components/
│   ├── ui/                     # shadcn/ui components
│   │   ├── avatar.tsx
│   │   ├── badge.tsx
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   ├── input.tsx
│   │   ├── label.tsx
│   │   └── separator.tsx
│   └── ProtectedRoute.tsx      # Auth route guard
├── contexts/
│   └── AuthContext.tsx         # Authentication state
├── lib/
│   └── utils.ts                # Utilities (cn helper)
├── pages/
│   ├── LoginPage.tsx           # Login/register page
│   └── MainPage.tsx            # Protected main page
├── App.tsx                     # Root component + routing
├── main.tsx                    # React DOM entry
├── App.css                     # App styles
└── index.css                   # Tailwind + theme variables
```

## Key Technologies

- **Vite** - Build tool with HMR
- **React 19** - UI framework
- **React Router 7** - Client-side routing
- **Tailwind CSS v4** - Utility-first CSS (Vite plugin)
- **shadcn/ui** - Component library (Radix UI + Tailwind)
- **Lucide React** - Icons

---

## Implementation Patterns

### Adding a New Page

1. Create the page component in `src/pages/`:

```typescript
// src/pages/PostsPage.tsx
import { useEffect, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import type { Post } from '@new-application/shared'

export function PostsPage() {
  const { token } = useAuth()
  const [posts, setPosts] = useState<Post[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchPosts() {
      try {
        const res = await fetch('/api/posts', {
          headers: { Authorization: `Bearer ${token}` },
        })
        const data = await res.json()
        if (data.success) {
          setPosts(data.data)
        } else {
          setError(data.error)
        }
      } catch {
        setError('Failed to fetch posts')
      } finally {
        setIsLoading(false)
      }
    }
    fetchPosts()
  }, [token])

  if (isLoading) {
    return <div className="flex justify-center p-8">Loading...</div>
  }

  if (error) {
    return <div className="p-8 text-destructive">{error}</div>
  }

  return (
    <div className="container mx-auto p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Posts</h1>
        <Button>Create Post</Button>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {posts.map((post) => (
          <Card key={post.id}>
            <CardHeader>
              <CardTitle>{post.title}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground line-clamp-3">
                {post.content}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}
```

2. Add route in `src/App.tsx`:

```typescript
import { PostsPage } from '@/pages/PostsPage'

// Inside Routes component
<Route
  path="/app/posts"
  element={
    <ProtectedRoute>
      <PostsPage />
    </ProtectedRoute>
  }
/>
```

---

### Adding a New Component

Create reusable components in `src/components/`:

```typescript
// src/components/PostCard.tsx
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import type { Post } from '@new-application/shared'

interface PostCardProps {
  post: Post
  onEdit?: () => void
  onDelete?: () => void
}

export function PostCard({ post, onEdit, onDelete }: PostCardProps) {
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="line-clamp-1">{post.title}</CardTitle>
          <Badge variant={post.published ? 'default' : 'secondary'}>
            {post.published ? 'Published' : 'Draft'}
          </Badge>
        </div>
      </CardHeader>
      <CardContent>
        <p className="text-muted-foreground line-clamp-3">{post.content}</p>
      </CardContent>
      {(onEdit || onDelete) && (
        <CardFooter className="gap-2">
          {onEdit && (
            <Button variant="outline" size="sm" onClick={onEdit}>
              Edit
            </Button>
          )}
          {onDelete && (
            <Button variant="destructive" size="sm" onClick={onDelete}>
              Delete
            </Button>
          )}
        </CardFooter>
      )}
    </Card>
  )
}
```

---

### Adding a shadcn/ui Component

Use the shadcn CLI to add new components:

```bash
cd packages/frontend
npx shadcn@latest add dialog
npx shadcn@latest add form
npx shadcn@latest add dropdown-menu
npx shadcn@latest add toast
```

Components are installed to `src/components/ui/` and can be customized.

---

### Creating a Form

```typescript
// src/components/CreatePostForm.tsx
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/contexts/AuthContext'

interface CreatePostFormProps {
  onSuccess?: () => void
}

export function CreatePostForm({ onSuccess }: CreatePostFormProps) {
  const { token } = useAuth()
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    try {
      const res = await fetch('/api/posts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ title, content }),
      })

      const data = await res.json()

      if (!data.success) {
        setError(data.error?.message || 'Failed to create post')
        return
      }

      setTitle('')
      setContent('')
      onSuccess?.()
    } catch {
      setError('Something went wrong')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      )}

      <div className="space-y-2">
        <Label htmlFor="title">Title</Label>
        <Input
          id="title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Post title"
          required
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="content">Content</Label>
        <textarea
          id="content"
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Write your post..."
          className="min-h-32 w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          required
        />
      </div>

      <Button type="submit" disabled={isLoading} className="w-full">
        {isLoading ? 'Creating...' : 'Create Post'}
      </Button>
    </form>
  )
}
```

---

### Adding a Context Provider

```typescript
// src/contexts/PostsContext.tsx
import { createContext, useContext, useState, useCallback, type ReactNode } from 'react'
import { useAuth } from './AuthContext'
import type { Post } from '@new-application/shared'

interface PostsContextType {
  posts: Post[]
  isLoading: boolean
  error: string | null
  fetchPosts: () => Promise<void>
  createPost: (data: { title: string; content: string }) => Promise<Post>
  deletePost: (id: string) => Promise<void>
}

const PostsContext = createContext<PostsContextType | null>(null)

export function PostsProvider({ children }: { children: ReactNode }) {
  const { token } = useAuth()
  const [posts, setPosts] = useState<Post[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchPosts = useCallback(async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await fetch('/api/posts', {
        headers: { Authorization: `Bearer ${token}` },
      })
      const data = await res.json()
      if (data.success) {
        setPosts(data.data)
      } else {
        setError(data.error)
      }
    } catch {
      setError('Failed to fetch posts')
    } finally {
      setIsLoading(false)
    }
  }, [token])

  const createPost = useCallback(
    async (postData: { title: string; content: string }) => {
      const res = await fetch('/api/posts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(postData),
      })
      const data = await res.json()
      if (!data.success) {
        throw new Error(data.error)
      }
      setPosts((prev) => [data.data, ...prev])
      return data.data
    },
    [token]
  )

  const deletePost = useCallback(
    async (id: string) => {
      await fetch(`/api/posts/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      })
      setPosts((prev) => prev.filter((p) => p.id !== id))
    },
    [token]
  )

  return (
    <PostsContext.Provider
      value={{ posts, isLoading, error, fetchPosts, createPost, deletePost }}
    >
      {children}
    </PostsContext.Provider>
  )
}

export function usePosts() {
  const context = useContext(PostsContext)
  if (!context) {
    throw new Error('usePosts must be used within PostsProvider')
  }
  return context
}
```

Add provider to `App.tsx`:

```typescript
<AuthProvider>
  <PostsProvider>
    <BrowserRouter>
      {/* routes */}
    </BrowserRouter>
  </PostsProvider>
</AuthProvider>
```

---

### Creating a Custom Hook

```typescript
// src/hooks/useApi.ts
import { useState, useCallback } from 'react'
import { useAuth } from '@/contexts/AuthContext'

interface UseApiOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE'
  body?: unknown
}

export function useApi<T>() {
  const { token } = useAuth()
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  const execute = useCallback(
    async (url: string, options: UseApiOptions = {}) => {
      setIsLoading(true)
      setError(null)

      try {
        const res = await fetch(url, {
          method: options.method || 'GET',
          headers: {
            'Content-Type': 'application/json',
            ...(token && { Authorization: `Bearer ${token}` }),
          },
          ...(options.body && { body: JSON.stringify(options.body) }),
        })

        const json = await res.json()

        if (!json.success) {
          setError(json.error?.message || json.error || 'Request failed')
          return null
        }

        setData(json.data)
        return json.data as T
      } catch {
        setError('Network error')
        return null
      } finally {
        setIsLoading(false)
      }
    },
    [token]
  )

  return { data, error, isLoading, execute }
}
```

Usage:

```typescript
const { data: posts, isLoading, error, execute } = useApi<Post[]>()

useEffect(() => {
  execute('/api/posts')
}, [execute])
```

---

## Styling Patterns

### Using Tailwind Classes

```typescript
// Responsive design
<div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">

// Conditional styling with cn()
import { cn } from '@/lib/utils'

<div className={cn(
  "rounded-lg border p-4",
  isActive && "border-primary bg-primary/5",
  isDisabled && "opacity-50 cursor-not-allowed"
)}>

// Dark mode (automatic with CSS variables)
<div className="bg-background text-foreground">
```

### Theme Colors (CSS Variables)

Available in `src/index.css`:

```css
/* Light mode colors */
--background     /* Page background */
--foreground     /* Default text */
--card           /* Card background */
--primary        /* Primary actions */
--secondary      /* Secondary actions */
--muted          /* Muted backgrounds */
--muted-foreground /* Muted text */
--accent         /* Accent color */
--destructive    /* Error/delete actions */
--border         /* Borders */
--input          /* Input borders */
--ring           /* Focus rings */
```

Usage:

```typescript
<div className="bg-background text-foreground">
<div className="bg-card border border-border">
<p className="text-muted-foreground">
<Button className="bg-primary text-primary-foreground">
```

---

## API Calls Pattern

All API calls go through the Vite proxy (`/api` → `localhost:3001`):

```typescript
// GET request
const res = await fetch('/api/posts')

// POST request with auth
const res = await fetch('/api/posts', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  },
  body: JSON.stringify({ title, content }),
})

// Handle response
const data = await res.json()
if (data.success) {
  // data.data contains the result
  // data.pagination if paginated
} else {
  // data.error contains error message
}
```

---

## Authentication

### Using Auth Context

```typescript
import { useAuth } from '@/contexts/AuthContext'

function MyComponent() {
  const { user, token, login, logout, isLoading } = useAuth()

  // Check if authenticated
  if (!user) return <Navigate to="/login" />

  // Use token for API calls
  fetch('/api/data', {
    headers: { Authorization: `Bearer ${token}` }
  })

  // Access user info
  return <span>Hello, {user.name || user.email}</span>
}
```

### Protected Routes

```typescript
import { ProtectedRoute } from '@/components/ProtectedRoute'

<Route
  path="/app/settings"
  element={
    <ProtectedRoute>
      <SettingsPage />
    </ProtectedRoute>
  }
/>
```

---

## shadcn/ui Components Reference

### Button Variants

```typescript
<Button>Default</Button>
<Button variant="secondary">Secondary</Button>
<Button variant="outline">Outline</Button>
<Button variant="ghost">Ghost</Button>
<Button variant="link">Link</Button>
<Button variant="destructive">Destructive</Button>

<Button size="sm">Small</Button>
<Button size="lg">Large</Button>
<Button size="icon"><Icon /></Button>
```

### Card Structure

```typescript
<Card>
  <CardHeader>
    <CardTitle>Title</CardTitle>
    <CardDescription>Description</CardDescription>
  </CardHeader>
  <CardContent>
    Content goes here
  </CardContent>
  <CardFooter>
    <Button>Action</Button>
  </CardFooter>
</Card>
```

### Badge Variants

```typescript
<Badge>Default</Badge>
<Badge variant="secondary">Secondary</Badge>
<Badge variant="outline">Outline</Badge>
<Badge variant="destructive">Destructive</Badge>
```

### Avatar

```typescript
<Avatar>
  <AvatarImage src={user.avatarUrl} alt={user.name} />
  <AvatarFallback>{user.name?.[0] || 'U'}</AvatarFallback>
</Avatar>
```

---

## File Organization

| Directory | Purpose |
|-----------|---------|
| `src/components/ui/` | shadcn/ui base components |
| `src/components/` | App-specific reusable components |
| `src/pages/` | Route page components |
| `src/contexts/` | React context providers |
| `src/hooks/` | Custom React hooks |
| `src/lib/` | Utilities and helpers |

---

## Path Aliases

Use `@/` to import from `src/`:

```typescript
import { Button } from '@/components/ui/button'
import { useAuth } from '@/contexts/AuthContext'
import { cn } from '@/lib/utils'
import type { Post } from '@new-application/shared'
```

---

## Development Commands

```bash
npm run dev:frontend     # Start dev server (port 5173)
npm run build:frontend   # Build for production
```

---

## Checklist for Frontend Changes

- [ ] Create page component in `src/pages/` if new route
- [ ] Add route to `src/App.tsx`
- [ ] Wrap with `<ProtectedRoute>` if authentication required
- [ ] Use shadcn/ui components from `@/components/ui/`
- [ ] Add new shadcn components with `npx shadcn@latest add <name>`
- [ ] Use `useAuth()` for authentication state
- [ ] Create context provider if shared state needed
- [ ] Use `@/` path alias for imports
- [ ] Import shared types from `@new-application/shared`
- [ ] Use Tailwind CSS classes for styling
- [ ] Use `cn()` helper for conditional classes
