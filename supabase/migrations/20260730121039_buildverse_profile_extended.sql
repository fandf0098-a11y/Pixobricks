-- BuildVerse Profile Extended Fields Migration
-- Adds: collections, achievements, projects_count, hours_built, pieces_scanned,
--       favourite_themes, experience_level, building_streak, weekly_stats

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. EXTEND user_profiles TABLE
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS location TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS website TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS experience_level TEXT DEFAULT 'Beginner',
ADD COLUMN IF NOT EXISTS building_streak INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS longest_streak INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS hours_built NUMERIC(8,1) DEFAULT 0,
ADD COLUMN IF NOT EXISTS pieces_scanned INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS projects_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS collections_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS favourite_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_likes_received INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS weekly_hours NUMERIC(5,1) DEFAULT 0,
ADD COLUMN IF NOT EXISTS weekly_pieces INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS weekly_builds INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. COLLECTIONS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    cover_image_url TEXT DEFAULT '',
    cover_image_label TEXT DEFAULT '',
    theme TEXT DEFAULT '',
    piece_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. ACHIEVEMENTS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    icon TEXT DEFAULT '🏆',
    icon_color INTEGER DEFAULT 7028735,
    earned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    achievement_type TEXT DEFAULT 'milestone',
    xp_reward INTEGER DEFAULT 0
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. INDEXES
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON public.collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_is_public ON public.collections(is_public);
CREATE INDEX IF NOT EXISTS idx_achievements_user_id ON public.achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_achievements_earned_at ON public.achievements(earned_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Sync followers_count on follows insert/delete
CREATE OR REPLACE FUNCTION public.sync_follow_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.user_profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
        UPDATE public.user_profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.user_profiles SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.following_id;
        UPDATE public.user_profiles SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Sync collections_count on collections insert/delete
CREATE OR REPLACE FUNCTION public.sync_collections_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.user_profiles SET collections_count = collections_count + 1 WHERE id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.user_profiles SET collections_count = GREATEST(0, collections_count - 1) WHERE id = OLD.user_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. ENABLE RLS
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RLS POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- collections: public read, own write
DROP POLICY IF EXISTS "public_read_collections" ON public.collections;
CREATE POLICY "public_read_collections"
ON public.collections FOR SELECT TO public
USING (is_public = true);

DROP POLICY IF EXISTS "users_manage_own_collections" ON public.collections;
CREATE POLICY "users_manage_own_collections"
ON public.collections FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- achievements: public read, own write
DROP POLICY IF EXISTS "public_read_achievements" ON public.achievements;
CREATE POLICY "public_read_achievements"
ON public.achievements FOR SELECT TO public
USING (true);

DROP POLICY IF EXISTS "users_manage_own_achievements" ON public.achievements;
CREATE POLICY "users_manage_own_achievements"
ON public.achievements FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS sync_follow_counts_trigger ON public.follows;
CREATE TRIGGER sync_follow_counts_trigger
    AFTER INSERT OR DELETE ON public.follows
    FOR EACH ROW EXECUTE FUNCTION public.sync_follow_counts();

DROP TRIGGER IF EXISTS sync_collections_count_trigger ON public.collections;
CREATE TRIGGER sync_collections_count_trigger
    AFTER INSERT OR DELETE ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.sync_collections_count();

DROP TRIGGER IF EXISTS update_collections_updated_at ON public.collections;
CREATE TRIGGER update_collections_updated_at
    BEFORE UPDATE ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. SEED EXTENDED PROFILE DATA
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    existing_user_id UUID;
    second_user_id UUID;
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'user_profiles'
    ) THEN
        SELECT id INTO existing_user_id FROM public.user_profiles ORDER BY created_at LIMIT 1;
        SELECT id INTO second_user_id FROM public.user_profiles ORDER BY created_at OFFSET 1 LIMIT 1;

        IF existing_user_id IS NOT NULL THEN
            -- Update extended profile fields for first user
            UPDATE public.user_profiles SET
                bio = 'Master builder with 10+ years of LEGO experience. Specialising in Technic and Star Wars sets.',
                location = 'Copenhagen, Denmark',
                experience_level = 'Master',
                building_streak = 21,
                longest_streak = 42,
                hours_built = 847.5,
                pieces_scanned = 12480,
                projects_count = 112,
                collections_count = 8,
                favourite_themes = ARRAY['Star Wars', 'Technic', 'City', 'Architecture'],
                following_count = 34,
                followers_count = 1240,
                total_likes_received = 28470,
                weekly_hours = 12.5,
                weekly_pieces = 340,
                weekly_builds = 3,
                last_active_at = now()
            WHERE id = existing_user_id;

            -- Achievements for first user
            INSERT INTO public.achievements (user_id, title, description, icon, icon_color, achievement_type, xp_reward, earned_at)
            VALUES
                (existing_user_id, 'Master Builder', 'Completed 100+ projects', '🏆', 7028735, 'milestone', 500, now() - interval '30 days'),
                (existing_user_id, '42-Day Streak', 'Built every day for 42 days', '🔥', 16739229, 'streak', 420, now() - interval '10 days'),
                (existing_user_id, 'Piece Scanner', 'Scanned 10,000+ pieces', '🔍', 54484, 'collection', 300, now() - interval '60 days'),
                (existing_user_id, 'Top Creator', 'Reached top 10 leaderboard', '⭐', 16766720, 'social', 250, now() - interval '20 days'),
                (existing_user_id, 'Diamond Tier', 'Earned 25,000+ XP', '💎', 54484, 'xp', 1000, now() - interval '5 days'),
                (existing_user_id, 'Viral Post', 'Post reached 2,000+ likes', '🚀', 16733085, 'social', 200, now() - interval '15 days')
            ON CONFLICT (id) DO NOTHING;

            -- Collections for first user
            INSERT INTO public.collections (user_id, title, description, cover_image_url, cover_image_label, theme, piece_count, is_public)
            VALUES
                (existing_user_id, 'Star Wars Fleet', 'My complete Star Wars collection from 2015-2024', 'https://images.unsplash.com/photo-1611068475024-c96a5ccadf2d?w=400', 'LEGO Star Wars Millennium Falcon model with detailed cockpit and landing gear', 'Star Wars', 3240, true),
                (existing_user_id, 'Technic Machines', 'Complex Technic builds with working mechanisms', 'https://images.pexels.com/photos/3861969/pexels-photo-3861969.jpeg?w=400', 'Complex mechanical LEGO Technic vehicle with gears and motors visible', 'Technic', 1870, true),
                (existing_user_id, 'City Skyline', 'Modular city buildings and infrastructure', 'https://images.pixabay.com/photo/2016/11/29/05/45/astronomy-1867616_1280.jpg?w=400', 'LEGO city skyline with tall buildings and street layout from above', 'City', 2100, true)
            ON CONFLICT (id) DO NOTHING;
        END IF;

        IF second_user_id IS NOT NULL THEN
            UPDATE public.user_profiles SET
                bio = 'Rising star in the LEGO community. Love neon and cyberpunk aesthetics.',
                experience_level = 'Advanced',
                building_streak = 8,
                longest_streak = 15,
                hours_built = 234.0,
                pieces_scanned = 4200,
                projects_count = 47,
                collections_count = 3,
                favourite_themes = ARRAY['Ninjago', 'City', 'Creator'],
                following_count = 89,
                followers_count = 430,
                total_likes_received = 12030,
                weekly_hours = 6.0,
                weekly_pieces = 120,
                weekly_builds = 2
            WHERE id = second_user_id;

            INSERT INTO public.achievements (user_id, title, description, icon, icon_color, achievement_type, xp_reward, earned_at)
            VALUES
                (second_user_id, 'Rising Star', 'Gained 400+ followers', '⭐', 16766720, 'social', 150, now() - interval '7 days'),
                (second_user_id, 'Speed Builder', 'Completed a build in under 1 hour', '⚡', 16766720, 'milestone', 100, now() - interval '14 days')
            ON CONFLICT (id) DO NOTHING;
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Seed data error: %', SQLERRM;
END $$;
