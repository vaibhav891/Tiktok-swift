# Engineering & Design Rules: Video-Based Social App (FeedTok)

> **Platform:** iOS 27+ / macOS  
> **Frameworks:** SwiftUI, AVKit, AVFoundation, AuthenticationServices, Observation  
> **Backend:** Supabase (Database, Auth, Storage) with Google Sign-In  
> **UI System:** Apple Liquid Glass  

---

## 1. Architectural Principles

1. **Separation of Concerns:**
   - **Models (`Untitled Project/Models/`):** Pure Swift immutable / value types (`Identifiable`, `Codable`, `Hashable`, `Sendable`).
   - **Services (`Untitled Project/Services/`):** State and API management using `@Observable` classes isolated to `@MainActor`.
   - **Views (`Untitled Project/Views/`):** Declarative SwiftUI components adhering to single-responsibility hierarchy.
   - **Components (`Untitled Project/Components/`):** Reusable design system primitives and AVFoundation wrappers.

2. **Concurrency & Modern Swift Guidelines:**
   - Always prefer Swift modern `async`/`await` over Combine pipelines.
   - Ensure UI mutations occur on `@MainActor`.
   - Use the Swift `Observation` framework (`@Observable`) instead of `ObservableObject` / `@Published`.
   - Avoid force unwrapping (`!`) in all production paths.

---

## 2. Liquid Glass Design System Rules

Liquid Glass forms a distinct functional layer that floats above the content layer, creating depth and fluidity while keeping video content visible.

### 2.1 Variant Guidelines
| Variant | SwiftUI API | Primary Use Cases | Guidance |
| :--- | :--- | :--- | :--- |
| **Clear Glass** | `.glassEffect(.clear, in: shape)` | Floating over media (videos, photos), action icons, playback controls, top pills | Use whenever elements overlay video media so underlying visual rich content peeks through. Always provide a subtle dark dimming gradient or 35% background opacity underneath. |
| **Regular Glass** | `.glassEffect(.regular, in: shape)` | Sheets, comment drawers, authentication cards, settings popovers | Blurs and adjusts luminosity of background content to maximize text legibility when significant text or dense controls are present. |

### 2.2 Do's and Don'ts
- **DO NOT** use Liquid Glass as the app's base background in the content layer. The content layer is reserved for video media and standard backgrounds.
- **DO** combine related interactive controls inside a `GlassEffectContainer` to allow smooth geometric morphing transitions between adjacent controls.
- **DO** use monochromatic white/vibrant symbols for action buttons over media, tinting only active states (e.g. red for liked hearts, yellow for bookmarked items).
- **DO** apply color accents sparingly to avoid visual fatigue over vibrant video content.

---

## 3. Feed & Video Playback Lifecycle

1. **Paging Feed Behavior:**
   - The feed must use vertical paging (`.scrollTargetBehavior(.paging)` with `.scrollTargetLayout()`).
   - Only the currently visible video post item is allowed to play. All off-screen video instances must pause (`isActive == false`) and release hardware resources.
2. **Seamless Looping:**
   - Use `AVPlayer` with `actionAtItemEnd = .none` and observe `.AVPlayerItemDidPlayToEndTime` via `NotificationCenter` to seek to `.zero` and replay.
   - **Avoid `AVPlayerLooper` for remote/streaming assets**: `AVPlayerLooper` requires asset duration to be known synchronously at initialization time and throws an `invalidArgumentException` if duration is 0, which breaks on remote streams or unbuffered assets.
3. **Local Fallback Generation:**
   - Use `SampleVideoGenerator` to create guaranteed 9:16 vertical MP4 video files locally on device/simulator. This ensures zero network latency, immunity to remote CDN 403 blocks, and instant 60fps playback out-of-the-box.
4. **Audio Session:**
   - Asynchronously configure `AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])` at startup so sound plays seamlessly regardless of the hardware silent switch without blocking the main launch thread.

---

## 4. Authentication & Access Control

1. **Guest Mode (Unauthenticated Browsing):**
   - Users are never forced to log in to browse the video feed, read captions, view profiles, or discover trending videos.
2. **Protected Actions:**
   - **Uploading / Posting Videos:** Strictly requires Google authentication.
   - **Adding Comments:** Prompts for Google authentication.
   - **Liking / Bookmarking:** Synced when authenticated; optimistic local update with auth fallback.
3. **Google Sign-In Implementation:**
   - Implemented via `ASWebAuthenticationSession` targeting Supabase Auth (`/auth/v1/authorize?provider=google`).
   - Redirect URL scheme: `myapp://auth/callback` handled by `.onOpenURL` in `MyApp.swift`.
   - Dual-Mode Architecture: When `SupabaseConfig.isConfigured` is `false`, the app defaults to built-in mock authentication with instant demo video upload support.

---

## 5. Supabase Database Schema & RLS Policies

Run this complete SQL migration script in your Supabase SQL Editor to provision the backend:

```sql
-- 1. Create Profiles Table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT DEFAULT '',
    follower_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    likes_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone can view (Guests included)
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles FOR SELECT USING (true);

-- Profiles: Users can update their own profile
CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);


-- 2. Create Posts Table
CREATE TABLE public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    caption TEXT NOT NULL,
    sound_title TEXT DEFAULT 'Original Sound',
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    author_name TEXT,
    author_avatar TEXT,
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    shares_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Posts
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Posts: Anyone can view feed
CREATE POLICY "Posts are viewable by everyone" 
ON public.posts FOR SELECT USING (true);

-- Posts: Only authenticated users can insert posts
CREATE POLICY "Authenticated users can create posts" 
ON public.posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Posts: Creators can update or delete their own posts
CREATE POLICY "Users can delete their own posts" 
ON public.posts FOR DELETE USING (auth.uid() = author_id);


-- 3. Create Comments Table
CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    text TEXT NOT NULL,
    likes_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on Comments
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- Comments: Anyone can read comments
CREATE POLICY "Comments are viewable by everyone" 
ON public.comments FOR SELECT USING (true);

-- Comments: Only authenticated users can post comments
CREATE POLICY "Authenticated users can create comments" 
ON public.comments FOR INSERT WITH CHECK (auth.role() = 'authenticated');


-- 4. Create Likes Table
CREATE TABLE public.post_likes (
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (post_id, user_id)
);

-- Enable RLS on Likes
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Likes are viewable by everyone" 
ON public.post_likes FOR SELECT USING (true);

CREATE POLICY "Authenticated users can toggle likes" 
ON public.post_likes FOR ALL USING (auth.uid() = user_id);


-- 5. Storage Bucket for Videos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('videos', 'videos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies
CREATE POLICY "Public videos are viewable by everyone"
ON storage.objects FOR SELECT USING (bucket_id = 'videos');

CREATE POLICY "Authenticated users can upload videos"
ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'videos' AND auth.role() = 'authenticated'
);
```

---

## 6. How to Connect Live Supabase Credentials

1. Open `Untitled Project/Services/SupabaseConfig.swift`.
2. Replace:
   - `projectURL` with your Supabase Project URL (`https://<project-ref>.supabase.co`).
   - `anonKey` with your project's Public Anon Key.
3. In your **Supabase Dashboard**:
   - Go to **Authentication > Providers > Google** and enable Google OAuth with your Google Client ID and Secret.
   - Add `myapp://auth/callback` to **URL Configuration > Redirect URLs**.
