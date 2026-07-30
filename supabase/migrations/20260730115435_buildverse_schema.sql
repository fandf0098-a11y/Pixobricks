-- BuildVerse Full Schema Migration
-- Covers: inventory_items, ai_builds, posts, creator_profiles, uploads, post_likes, post_bookmarks, follows

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ENUM TYPES
-- ─────────────────────────────────────────────────────────────────────────────
DROP TYPE IF EXISTS public.brick_status CASCADE;
CREATE TYPE public.brick_status AS ENUM ('active', 'warning', 'inactive');

DROP TYPE IF EXISTS public.post_type CASCADE;
CREATE TYPE public.post_type AS ENUM ('project', 'image', 'video', 'instructions');

DROP TYPE IF EXISTS public.upload_type CASCADE;
CREATE TYPE public.upload_type AS ENUM ('image', 'video', 'document', 'model');

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CORE TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- User profiles (intermediary for auth.users)
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    username TEXT UNIQUE,
    avatar_url TEXT DEFAULT '',
    bio TEXT DEFAULT '',
    badge TEXT DEFAULT 'Builder',
    badge_color INTEGER DEFAULT 7028735,
    xp INTEGER DEFAULT 0,
    streak INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Inventory items (brick scans)
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Bricks',
    piece_id TEXT NOT NULL DEFAULT '',
    count INTEGER NOT NULL DEFAULT 0,
    image_url TEXT DEFAULT '',
    semantic_label TEXT DEFAULT '',
    brick_status public.brick_status DEFAULT 'active'::public.brick_status,
    is_favorite BOOLEAN DEFAULT false,
    last_scanned TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- AI builds
CREATE TABLE IF NOT EXISTS public.ai_builds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    prompt TEXT NOT NULL,
    style TEXT NOT NULL DEFAULT 'Classic',
    title TEXT NOT NULL DEFAULT '',
    pieces INTEGER DEFAULT 0,
    difficulty TEXT DEFAULT 'Medium',
    build_time TEXT DEFAULT '',
    image_url TEXT DEFAULT '',
    match_percent INTEGER DEFAULT 0,
    accent_color INTEGER DEFAULT 7028735,
    is_saved BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Community posts
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    post_type public.post_type NOT NULL DEFAULT 'project'::public.post_type,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    image_url TEXT DEFAULT '',
    image_label TEXT DEFAULT '',
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    bookmarks_count INTEGER DEFAULT 0,
    remixes_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Post likes (junction)
CREATE TABLE IF NOT EXISTS public.post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Post bookmarks (junction)
CREATE TABLE IF NOT EXISTS public.post_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Follows (creator follow system)
CREATE TABLE IF NOT EXISTS public.follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Uploads (media files metadata)
CREATE TABLE IF NOT EXISTS public.uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
    upload_type public.upload_type NOT NULL DEFAULT 'image'::public.upload_type,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_size INTEGER DEFAULT 0,
    mime_type TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. UNIQUE CONSTRAINTS (via partial indexes)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS idx_post_likes_unique ON public.post_likes (post_id, user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_post_bookmarks_unique ON public.post_bookmarks (post_id, user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_follows_unique ON public.follows (follower_id, following_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. INDEXES
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_inventory_items_user_id ON public.inventory_items(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_category ON public.inventory_items(category);
CREATE INDEX IF NOT EXISTS idx_ai_builds_user_id ON public.ai_builds(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_likes_count ON public.posts(likes_count DESC);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_bookmarks_user_id ON public.post_bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON public.follows(following_id);
CREATE INDEX IF NOT EXISTS idx_uploads_user_id ON public.uploads(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, avatar_url, username)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- Increment post likes count
CREATE OR REPLACE FUNCTION public.increment_likes(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = post_uuid;
END;
$$;

-- Decrement post likes count
CREATE OR REPLACE FUNCTION public.decrement_likes(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = post_uuid;
END;
$$;

-- Increment bookmarks count
CREATE OR REPLACE FUNCTION public.increment_bookmarks(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.posts SET bookmarks_count = bookmarks_count + 1 WHERE id = post_uuid;
END;
$$;

-- Decrement bookmarks count
CREATE OR REPLACE FUNCTION public.decrement_bookmarks(post_uuid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.posts SET bookmarks_count = GREATEST(0, bookmarks_count - 1) WHERE id = post_uuid;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. ENABLE RLS
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_builds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RLS POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- user_profiles: own row management
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles FOR ALL TO authenticated
USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "public_read_user_profiles" ON public.user_profiles;
CREATE POLICY "public_read_user_profiles"
ON public.user_profiles FOR SELECT TO public
USING (true);

-- inventory_items: own items
DROP POLICY IF EXISTS "users_manage_own_inventory_items" ON public.inventory_items;
CREATE POLICY "users_manage_own_inventory_items"
ON public.inventory_items FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ai_builds: own builds
DROP POLICY IF EXISTS "users_manage_own_ai_builds" ON public.ai_builds;
CREATE POLICY "users_manage_own_ai_builds"
ON public.ai_builds FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- posts: public read, own write
DROP POLICY IF EXISTS "public_read_posts" ON public.posts;
CREATE POLICY "public_read_posts"
ON public.posts FOR SELECT TO public
USING (true);

DROP POLICY IF EXISTS "users_manage_own_posts" ON public.posts;
CREATE POLICY "users_manage_own_posts"
ON public.posts FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- post_likes: own likes
DROP POLICY IF EXISTS "users_manage_own_post_likes" ON public.post_likes;
CREATE POLICY "users_manage_own_post_likes"
ON public.post_likes FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "public_read_post_likes" ON public.post_likes;
CREATE POLICY "public_read_post_likes"
ON public.post_likes FOR SELECT TO public
USING (true);

-- post_bookmarks: own bookmarks
DROP POLICY IF EXISTS "users_manage_own_post_bookmarks" ON public.post_bookmarks;
CREATE POLICY "users_manage_own_post_bookmarks"
ON public.post_bookmarks FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- follows: own follows
DROP POLICY IF EXISTS "users_manage_own_follows" ON public.follows;
CREATE POLICY "users_manage_own_follows"
ON public.follows FOR ALL TO authenticated
USING (follower_id = auth.uid()) WITH CHECK (follower_id = auth.uid());

DROP POLICY IF EXISTS "public_read_follows" ON public.follows;
CREATE POLICY "public_read_follows"
ON public.follows FOR SELECT TO public
USING (true);

-- uploads: own uploads
DROP POLICY IF EXISTS "users_manage_own_uploads" ON public.uploads;
CREATE POLICY "users_manage_own_uploads"
ON public.uploads FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_inventory_items_updated_at ON public.inventory_items;
CREATE TRIGGER update_inventory_items_updated_at
    BEFORE UPDATE ON public.inventory_items
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_posts_updated_at ON public.posts;
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. SEED DATA
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    user1_uuid UUID := gen_random_uuid();
    user2_uuid UUID := gen_random_uuid();
    user3_uuid UUID := gen_random_uuid();
    post1_uuid UUID := gen_random_uuid();
    post2_uuid UUID := gen_random_uuid();
    post3_uuid UUID := gen_random_uuid();
BEGIN
    -- Create auth users (trigger creates user_profiles automatically)
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (user1_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'brickwizard@buildverse.app', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         jsonb_build_object('full_name', 'BrickWizard', 'username', 'brickwizard', 'avatar_url', 'https://images.unsplash.com/photo-1531218532332-2ad238829d9a?w=200'),
         jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user2_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'neonbuilder@buildverse.app', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         jsonb_build_object('full_name', 'NeonBuilder', 'username', 'neonbuilder', 'avatar_url', 'https://images.unsplash.com/photo-1670841063394-d6909f7529aa?w=200'),
         jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user3_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'treebuilder@buildverse.app', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         jsonb_build_object('full_name', 'TreeBuilder', 'username', 'treebuilder', 'avatar_url', 'https://images.unsplash.com/photo-1628258946069-bffa042dff5e?w=200'),
         jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null)
    ON CONFLICT (id) DO NOTHING;

    -- Update user_profiles with badge info (trigger creates them, we update extra fields)
    UPDATE public.user_profiles SET badge = 'Master Builder', badge_color = 7028735, xp = 27800, streak = 21
    WHERE id = user1_uuid;
    UPDATE public.user_profiles SET badge = 'Rising Star', badge_color = 16739229, xp = 12400, streak = 8
    WHERE id = user2_uuid;
    UPDATE public.user_profiles SET badge = 'Instructor', badge_color = 54484, xp = 18900, streak = 15
    WHERE id = user3_uuid;

    -- Inventory items for user1
    INSERT INTO public.inventory_items (id, user_id, name, category, piece_id, count, image_url, semantic_label, brick_status, is_favorite, last_scanned)
    VALUES
        (gen_random_uuid(), user1_uuid, 'Classic 2x4 Red Brick', 'Bricks', '3001', 48,
         'https://img.rocket.new/generatedImages/rocket_gen_img_11337548c-1785411151420.png',
         'Classic red LEGO 2x4 brick, rectangular with 8 round studs on top',
         'active'::public.brick_status, true, now() - interval '2 days'),
        (gen_random_uuid(), user1_uuid, '1x2 Blue Plate', 'Plates', '3023', 124,
         'https://img.rocket.new/generatedImages/rocket_gen_img_18eb955fe-1775472546149.png',
         'Blue LEGO 1x2 flat plate, thin rectangular piece with 2 round studs',
         'active'::public.brick_status, false, now() - interval '1 day'),
        (gen_random_uuid(), user1_uuid, 'Technic Axle 8L', 'Technic', '3707', 12,
         'https://img.rocket.new/generatedImages/rocket_gen_img_1741d33d0-1785411152080.png',
         'Grey LEGO Technic axle, long cylindrical rod for mechanical builds',
         'active'::public.brick_status, false, now() - interval '5 days'),
        (gen_random_uuid(), user1_uuid, 'Yellow 2x2 Corner Brick', 'Bricks', '2357', 6,
         'https://img.rocket.new/generatedImages/rocket_gen_img_1cebde495-1785411151523.png',
         'Yellow LEGO L-shaped corner brick with studs on two perpendicular faces',
         'warning'::public.brick_status, true, now() - interval '10 days'),
        (gen_random_uuid(), user1_uuid, 'Classic Minifig Explorer', 'Minifigs', 'MF-EXP-01', 2,
         'https://img.rocket.new/generatedImages/rocket_gen_img_196041d8f-1773589255786.png',
         'LEGO explorer minifigure wearing khaki hat and backpack, smiling face print',
         'active'::public.brick_status, true, now() - interval '3 days'),
        (gen_random_uuid(), user1_uuid, '2x4 Green Plate', 'Plates', '3020', 87,
         'https://img.rocket.new/generatedImages/rocket_gen_img_1e5edc5d9-1785411151084.png',
         'Green LEGO 2x4 flat plate, thin wide piece with 8 round studs on top',
         'active'::public.brick_status, false, now() - interval '1 day'),
        (gen_random_uuid(), user1_uuid, 'Transparent Blue 1x1 Round', 'Special', '4073', 3,
         'https://img.rocket.new/generatedImages/rocket_gen_img_179043869-1765722092169.png',
         'Transparent blue LEGO 1x1 round stud piece, small circular jewel-like brick',
         'warning'::public.brick_status, false, now() - interval '15 days'),
        (gen_random_uuid(), user1_uuid, 'White 1x4 Brick', 'Bricks', '3010', 62,
         'https://img.rocket.new/generatedImages/rocket_gen_img_1711edc97-1775472544236.png',
         'White LEGO 1x4 rectangular brick with 4 round studs on top surface',
         'active'::public.brick_status, false, now() - interval '2 days')
    ON CONFLICT (id) DO NOTHING;

    -- AI builds for user1
    INSERT INTO public.ai_builds (id, user_id, prompt, style, title, pieces, difficulty, build_time, image_url, match_percent, accent_color, is_saved)
    VALUES
        (gen_random_uuid(), user1_uuid, 'Medieval Castle', 'Classic', 'Medieval Castle', 847, 'Advanced', '4-6 hrs',
         'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400', 94, 7028735, true),
        (gen_random_uuid(), user1_uuid, 'Space Station', 'Technic', 'Space Station Alpha', 1240, 'Expert', '8-10 hrs',
         'https://images.pexels.com/photos/586063/pexels-photo-586063.jpeg?w=400', 88, 54484, false)
    ON CONFLICT (id) DO NOTHING;

    -- Community posts
    INSERT INTO public.posts (id, user_id, post_type, title, description, image_url, image_label, tags, likes_count, comments_count, bookmarks_count, remixes_count)
    VALUES
        (post1_uuid, user1_uuid, 'project'::public.post_type,
         'Millennium Falcon — 7,541 pieces',
         'Took 3 months to complete. Used custom lighting kit from BrickGlow. Step-by-step instructions included!',
         'https://images.unsplash.com/photo-1611068475024-c96a5ccadf2d',
         'Detailed LEGO Millennium Falcon spaceship model with custom LED lighting on dark background',
         ARRAY['Star Wars', 'Advanced', 'Lighting'],
         2847, 312, 891, 47),
        (post2_uuid, user2_uuid, 'image'::public.post_type,
         'Neon City Skyline — Micro Build',
         'Inspired by cyberpunk aesthetics. All standard bricks, no special pieces needed.',
         'https://img.rocket.new/generatedImages/rocket_gen_img_10549a544-1785411735807.png',
         'Colorful LEGO city skyline with neon-colored buildings and tiny street lights at night',
         ARRAY['Cityscape', 'Micro', 'Neon'],
         1203, 89, 445, 23),
        (post3_uuid, user3_uuid, 'instructions'::public.post_type,
         'Modular Treehouse — Build Guide',
         '47-step illustrated guide. Beginner friendly. Includes parts list and substitution suggestions.',
         'https://img.rocket.new/generatedImages/rocket_gen_img_1aabeda96-1769248824295.png',
         'LEGO treehouse model with green leaves, wooden brown trunk and small windows surrounded by nature',
         ARRAY['Tutorial', 'Beginner', 'Nature'],
         3421, 567, 1230, 112)
    ON CONFLICT (id) DO NOTHING;

    -- Follows
    INSERT INTO public.follows (follower_id, following_id)
    VALUES
        (user2_uuid, user1_uuid),
        (user3_uuid, user1_uuid),
        (user1_uuid, user3_uuid)
    ON CONFLICT DO NOTHING;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Seed data error: %', SQLERRM;
END $$;
