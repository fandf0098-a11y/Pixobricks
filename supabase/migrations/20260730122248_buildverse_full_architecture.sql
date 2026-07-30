-- ============================================================
-- BuildVerse Full Backend Architecture Migration
-- Timestamp: 20260730122248
-- Covers: Storage, Comments, Notifications, Remixes,
--         Collections, Build Sessions, Push Tokens,
--         Offline Sync Queue, Indexes, RLS, Realtime,
--         Backup helpers, Edge Function support
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. STORAGE BUCKETS (via SQL helper function)
-- ────────────────────────────────────────────────────────────
-- Create storage buckets for BuildVerse assets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars',    'avatars',    true,  5242880,   ARRAY['image/jpeg','image/png','image/webp','image/gif']),
  ('post-media', 'post-media', true,  52428800,  ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']),
  ('build-models','build-models', false, 104857600, ARRAY['model/gltf+json','model/gltf-binary','application/octet-stream']),
  ('documents',  'documents',  false, 10485760,  ARRAY['application/pdf','text/plain','application/json'])
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: avatars bucket (public read, owner write)
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_owner_upload" ON storage.objects;
CREATE POLICY "avatars_owner_upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Storage RLS: post-media bucket (public read, owner write)
DROP POLICY IF EXISTS "post_media_public_read" ON storage.objects;
CREATE POLICY "post_media_public_read"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'post-media');

DROP POLICY IF EXISTS "post_media_owner_upload" ON storage.objects;
CREATE POLICY "post_media_owner_upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'post-media' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "post_media_owner_delete" ON storage.objects;
CREATE POLICY "post_media_owner_delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'post-media' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Storage RLS: build-models bucket (private, owner only)
DROP POLICY IF EXISTS "build_models_owner_all" ON storage.objects;
CREATE POLICY "build_models_owner_all"
ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'build-models' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'build-models' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Storage RLS: documents bucket (private, owner only)
DROP POLICY IF EXISTS "documents_owner_all" ON storage.objects;
CREATE POLICY "documents_owner_all"
ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ────────────────────────────────────────────────────────────
-- 2. NEW TABLES
-- ────────────────────────────────────────────────────────────

-- 2a. Comments (threaded, supports parent_id for replies)
CREATE TABLE IF NOT EXISTS public.comments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  parent_id     UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  content       TEXT NOT NULL,
  likes_count   INTEGER DEFAULT 0,
  is_edited     BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2b. Comment likes
CREATE TABLE IF NOT EXISTS public.comment_likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2c. Notifications
DROP TYPE IF EXISTS public.notification_type CASCADE;
CREATE TYPE public.notification_type AS ENUM (
  'like', 'comment', 'follow', 'mention', 'remix',
  'achievement', 'system', 'build_complete'
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  actor_id      UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  type          public.notification_type NOT NULL,
  title         TEXT NOT NULL DEFAULT '',
  body          TEXT NOT NULL DEFAULT '',
  data          JSONB DEFAULT '{}'::jsonb,
  is_read       BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2d. Push notification tokens
CREATE TABLE IF NOT EXISTS public.push_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  token      TEXT NOT NULL,
  platform   TEXT NOT NULL DEFAULT 'android',
  is_active  BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2e. Post remixes (tracks which post was remixed from which)
CREATE TABLE IF NOT EXISTS public.post_remixes (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  remix_id       UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2f. Collection items (junction: collections ↔ posts)
CREATE TABLE IF NOT EXISTS public.collection_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
  post_id       UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  added_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2g. Build sessions (tracks active building time for XP/stats)
CREATE TABLE IF NOT EXISTS public.build_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  ai_build_id  UUID REFERENCES public.ai_builds(id) ON DELETE SET NULL,
  started_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  ended_at     TIMESTAMPTZ,
  duration_min INTEGER DEFAULT 0,
  pieces_used  INTEGER DEFAULT 0,
  notes        TEXT DEFAULT ''
);

-- 2h. Offline sync queue (client-side mutations pending upload)
DROP TYPE IF EXISTS public.sync_operation CASCADE;
CREATE TYPE public.sync_operation AS ENUM ('insert', 'update', 'delete');

CREATE TABLE IF NOT EXISTS public.sync_queue (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  table_name   TEXT NOT NULL,
  operation    public.sync_operation NOT NULL,
  record_id    UUID,
  payload      JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_processed BOOLEAN DEFAULT false,
  retry_count  INTEGER DEFAULT 0,
  error_msg    TEXT,
  created_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  processed_at TIMESTAMPTZ
);

-- 2i. App config / feature flags (server-driven config)
CREATE TABLE IF NOT EXISTS public.app_config (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ────────────────────────────────────────────────────────────
-- 3. POSTGRES INDEXES (performance-critical queries)
-- ────────────────────────────────────────────────────────────

-- user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_username       ON public.user_profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_xp_desc        ON public.user_profiles(xp DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_last_active    ON public.user_profiles(last_active_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_experience     ON public.user_profiles(experience_level);

-- inventory_items
CREATE INDEX IF NOT EXISTS idx_inventory_user_id            ON public.inventory_items(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_category           ON public.inventory_items(category);
CREATE INDEX IF NOT EXISTS idx_inventory_is_favorite        ON public.inventory_items(user_id, is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_inventory_piece_id           ON public.inventory_items(piece_id);

-- ai_builds
CREATE INDEX IF NOT EXISTS idx_ai_builds_user_id            ON public.ai_builds(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_builds_created_at         ON public.ai_builds(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_builds_is_saved           ON public.ai_builds(user_id, is_saved) WHERE is_saved = true;

-- posts
CREATE INDEX IF NOT EXISTS idx_posts_user_id                ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at             ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_likes_count            ON public.posts(likes_count DESC);
CREATE INDEX IF NOT EXISTS idx_posts_post_type              ON public.posts(post_type);
CREATE INDEX IF NOT EXISTS idx_posts_tags_gin               ON public.posts USING GIN(tags);

-- post_likes / post_bookmarks
CREATE UNIQUE INDEX IF NOT EXISTS idx_post_likes_unique     ON public.post_likes(post_id, user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id           ON public.post_likes(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_post_bookmarks_unique ON public.post_bookmarks(post_id, user_id);
CREATE INDEX IF NOT EXISTS idx_post_bookmarks_user_id       ON public.post_bookmarks(user_id);

-- follows
CREATE UNIQUE INDEX IF NOT EXISTS idx_follows_unique        ON public.follows(follower_id, following_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower_id          ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id         ON public.follows(following_id);

-- comments
CREATE INDEX IF NOT EXISTS idx_comments_post_id             ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id             ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id           ON public.comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at          ON public.comments(created_at DESC);

-- comment_likes
CREATE UNIQUE INDEX IF NOT EXISTS idx_comment_likes_unique  ON public.comment_likes(comment_id, user_id);

-- notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id        ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread         ON public.notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at     ON public.notifications(created_at DESC);

-- push_tokens
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_tokens_unique    ON public.push_tokens(user_id, token);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active           ON public.push_tokens(user_id) WHERE is_active = true;

-- collections
CREATE INDEX IF NOT EXISTS idx_collections_user_id          ON public.collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_collection  ON public.collection_items(collection_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_collection_items_unique ON public.collection_items(collection_id, post_id);

-- build_sessions
CREATE INDEX IF NOT EXISTS idx_build_sessions_user_id       ON public.build_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_build_sessions_started_at    ON public.build_sessions(started_at DESC);

-- sync_queue
CREATE INDEX IF NOT EXISTS idx_sync_queue_user_pending      ON public.sync_queue(user_id, is_processed) WHERE is_processed = false;
CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at        ON public.sync_queue(created_at ASC);

-- achievements
CREATE INDEX IF NOT EXISTS idx_achievements_user_id         ON public.achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_achievements_type            ON public.achievements(achievement_type);

-- uploads
CREATE INDEX IF NOT EXISTS idx_uploads_user_id              ON public.uploads(user_id);
CREATE INDEX IF NOT EXISTS idx_uploads_post_id              ON public.uploads(post_id);

-- ────────────────────────────────────────────────────────────
-- 4. FUNCTIONS (must be before RLS policies that reference them)
-- ────────────────────────────────────────────────────────────

-- 4a. Update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

-- 4b. Auto-increment comments_count on posts
CREATE OR REPLACE FUNCTION public.increment_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$;

-- 4c. Auto-increment remixes_count on posts
CREATE OR REPLACE FUNCTION public.increment_remixes_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.posts SET remixes_count = remixes_count + 1 WHERE id = NEW.original_id;
  RETURN NEW;
END;
$$;

-- 4d. Update user stats when build session ends
CREATE OR REPLACE FUNCTION public.apply_build_session_stats()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.ended_at IS NOT NULL AND OLD.ended_at IS NULL THEN
    UPDATE public.user_profiles
    SET
      hours_built   = hours_built + (NEW.duration_min::numeric / 60),
      pieces_scanned = pieces_scanned + NEW.pieces_used,
      weekly_hours  = weekly_hours + (NEW.duration_min::numeric / 60),
      weekly_pieces = weekly_pieces + NEW.pieces_used,
      xp            = xp + GREATEST(1, NEW.duration_min / 5),
      last_active_at = CURRENT_TIMESTAMP,
      updated_at    = CURRENT_TIMESTAMP
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

-- 4e. Create notification helper
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id  UUID,
  p_actor_id UUID,
  p_type     public.notification_type,
  p_title    TEXT,
  p_body     TEXT,
  p_data     JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  notif_id UUID;
BEGIN
  -- Don't notify yourself
  IF p_user_id = p_actor_id THEN
    RETURN NULL;
  END IF;
  INSERT INTO public.notifications (user_id, actor_id, type, title, body, data)
  VALUES (p_user_id, p_actor_id, p_type, p_title, p_body, p_data)
  RETURNING id INTO notif_id;
  RETURN notif_id;
END;
$$;

-- 4f. Auto-notify on new like
CREATE OR REPLACE FUNCTION public.notify_on_like()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  post_owner_id UUID;
  liker_name    TEXT;
BEGIN
  SELECT user_id INTO post_owner_id FROM public.posts WHERE id = NEW.post_id LIMIT 1;
  SELECT COALESCE(username, full_name) INTO liker_name FROM public.user_profiles WHERE id = NEW.user_id LIMIT 1;
  PERFORM public.create_notification(
    post_owner_id, NEW.user_id, 'like'::public.notification_type,
    'New Like', liker_name || ' liked your build',
    jsonb_build_object('post_id', NEW.post_id)
  );
  RETURN NEW;
END;
$$;

-- 4g. Auto-notify on new comment
CREATE OR REPLACE FUNCTION public.notify_on_comment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  post_owner_id UUID;
  commenter_name TEXT;
BEGIN
  SELECT user_id INTO post_owner_id FROM public.posts WHERE id = NEW.post_id LIMIT 1;
  SELECT COALESCE(username, full_name) INTO commenter_name FROM public.user_profiles WHERE id = NEW.user_id LIMIT 1;
  PERFORM public.create_notification(
    post_owner_id, NEW.user_id, 'comment'::public.notification_type,
    'New Comment', commenter_name || ' commented on your build',
    jsonb_build_object('post_id', NEW.post_id, 'comment_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

-- 4h. Auto-notify on new follow
CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  follower_name TEXT;
BEGIN
  SELECT COALESCE(username, full_name) INTO follower_name FROM public.user_profiles WHERE id = NEW.follower_id LIMIT 1;
  PERFORM public.create_notification(
    NEW.following_id, NEW.follower_id, 'follow'::public.notification_type,
    'New Follower', follower_name || ' started following you',
    jsonb_build_object('follower_id', NEW.follower_id)
  );
  RETURN NEW;
END;
$$;

-- 4i. Process sync queue entry (called by Edge Function)
CREATE OR REPLACE FUNCTION public.process_sync_entry(p_entry_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.sync_queue
  SET is_processed = true, processed_at = CURRENT_TIMESTAMP
  WHERE id = p_entry_id;
  RETURN FOUND;
END;
$$;

-- 4j. Get unread notification count
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COUNT(*)::INTEGER FROM public.notifications
  WHERE user_id = p_user_id AND is_read = false;
$$;

-- 4k. Mark all notifications read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(p_user_id UUID)
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.notifications SET is_read = true
  WHERE user_id = p_user_id AND is_read = false;
$$;

-- 4l. Weekly stats reset (called by scheduled Edge Function)
CREATE OR REPLACE FUNCTION public.reset_weekly_stats()
RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.user_profiles
  SET weekly_hours = 0, weekly_pieces = 0, weekly_builds = 0;
$$;

-- 4m. Backup snapshot function (creates a JSONB snapshot of user data)
CREATE OR REPLACE FUNCTION public.get_user_backup_snapshot(p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'profile',      (SELECT row_to_json(p) FROM public.user_profiles p WHERE id = p_user_id),
    'inventory',    (SELECT jsonb_agg(row_to_json(i)) FROM public.inventory_items i WHERE user_id = p_user_id),
    'ai_builds',    (SELECT jsonb_agg(row_to_json(b)) FROM public.ai_builds b WHERE user_id = p_user_id),
    'collections',  (SELECT jsonb_agg(row_to_json(c)) FROM public.collections c WHERE user_id = p_user_id),
    'achievements', (SELECT jsonb_agg(row_to_json(a)) FROM public.achievements a WHERE user_id = p_user_id),
    'exported_at',  CURRENT_TIMESTAMP
  ) INTO result;
  RETURN result;
END;
$$;

-- 4n. is_valid_user helper (for non-user tables)
CREATE OR REPLACE FUNCTION public.is_valid_user()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND is_active = true
  );
$$;

-- ────────────────────────────────────────────────────────────
-- 5. ENABLE RLS ON NEW TABLES
-- ────────────────────────────────────────────────────────────

ALTER TABLE public.comments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_remixes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.build_sessions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_queue        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config        ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────
-- 6. RLS POLICIES
-- ────────────────────────────────────────────────────────────

-- comments: public read, owner write
DROP POLICY IF EXISTS "comments_public_read" ON public.comments;
CREATE POLICY "comments_public_read"
ON public.comments FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "comments_owner_insert" ON public.comments;
CREATE POLICY "comments_owner_insert"
ON public.comments FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "comments_owner_update" ON public.comments;
CREATE POLICY "comments_owner_update"
ON public.comments FOR UPDATE TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "comments_owner_delete" ON public.comments;
CREATE POLICY "comments_owner_delete"
ON public.comments FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- comment_likes: public read, owner write
DROP POLICY IF EXISTS "comment_likes_public_read" ON public.comment_likes;
CREATE POLICY "comment_likes_public_read"
ON public.comment_likes FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "comment_likes_owner_manage" ON public.comment_likes;
CREATE POLICY "comment_likes_owner_manage"
ON public.comment_likes FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- notifications: private to owner
DROP POLICY IF EXISTS "notifications_owner_all" ON public.notifications;
CREATE POLICY "notifications_owner_all"
ON public.notifications FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- push_tokens: private to owner
DROP POLICY IF EXISTS "push_tokens_owner_all" ON public.push_tokens;
CREATE POLICY "push_tokens_owner_all"
ON public.push_tokens FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- post_remixes: public read, owner write
DROP POLICY IF EXISTS "post_remixes_public_read" ON public.post_remixes;
CREATE POLICY "post_remixes_public_read"
ON public.post_remixes FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "post_remixes_authenticated_insert" ON public.post_remixes;
CREATE POLICY "post_remixes_authenticated_insert"
ON public.post_remixes FOR INSERT TO authenticated
WITH CHECK (true);

-- collection_items: owner manages, public reads public collections
DROP POLICY IF EXISTS "collection_items_read" ON public.collection_items;
CREATE POLICY "collection_items_read"
ON public.collection_items FOR SELECT TO public
USING (
  EXISTS (
    SELECT 1 FROM public.collections c
    WHERE c.id = collection_id AND (c.is_public = true OR c.user_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "collection_items_owner_write" ON public.collection_items;
CREATE POLICY "collection_items_owner_write"
ON public.collection_items FOR ALL TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_id AND c.user_id = auth.uid())
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_id AND c.user_id = auth.uid())
);

-- build_sessions: private to owner
DROP POLICY IF EXISTS "build_sessions_owner_all" ON public.build_sessions;
CREATE POLICY "build_sessions_owner_all"
ON public.build_sessions FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- sync_queue: private to owner
DROP POLICY IF EXISTS "sync_queue_owner_all" ON public.sync_queue;
CREATE POLICY "sync_queue_owner_all"
ON public.sync_queue FOR ALL TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- app_config: public read, no write from client
DROP POLICY IF EXISTS "app_config_public_read" ON public.app_config;
CREATE POLICY "app_config_public_read"
ON public.app_config FOR SELECT TO public USING (true);

-- ────────────────────────────────────────────────────────────
-- 7. TRIGGERS
-- ────────────────────────────────────────────────────────────

-- updated_at triggers
DROP TRIGGER IF EXISTS set_updated_at_comments ON public.comments;
CREATE TRIGGER set_updated_at_comments
  BEFORE UPDATE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_push_tokens ON public.push_tokens;
CREATE TRIGGER set_updated_at_push_tokens
  BEFORE UPDATE ON public.push_tokens
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- comments count triggers
DROP TRIGGER IF EXISTS on_comment_insert ON public.comments;
CREATE TRIGGER on_comment_insert
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.increment_comments_count();

DROP TRIGGER IF EXISTS on_comment_delete ON public.comments;
CREATE TRIGGER on_comment_delete
  AFTER DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.decrement_comments_count();

-- remixes count trigger
DROP TRIGGER IF EXISTS on_remix_insert ON public.post_remixes;
CREATE TRIGGER on_remix_insert
  AFTER INSERT ON public.post_remixes
  FOR EACH ROW EXECUTE FUNCTION public.increment_remixes_count();

-- build session stats trigger
DROP TRIGGER IF EXISTS on_build_session_update ON public.build_sessions;
CREATE TRIGGER on_build_session_update
  AFTER UPDATE ON public.build_sessions
  FOR EACH ROW EXECUTE FUNCTION public.apply_build_session_stats();

-- notification triggers
DROP TRIGGER IF EXISTS on_post_like_notify ON public.post_likes;
CREATE TRIGGER on_post_like_notify
  AFTER INSERT ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_like();

DROP TRIGGER IF EXISTS on_comment_notify ON public.comments;
CREATE TRIGGER on_comment_notify
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_comment();

DROP TRIGGER IF EXISTS on_follow_notify ON public.follows;
CREATE TRIGGER on_follow_notify
  AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_follow();

-- ────────────────────────────────────────────────────────────
-- 8. REALTIME PUBLICATION
-- ────────────────────────────────────────────────────────────

-- Enable realtime for key tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.comments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.follows;

-- ────────────────────────────────────────────────────────────
-- 9. APP CONFIG SEED DATA
-- ────────────────────────────────────────────────────────────

INSERT INTO public.app_config (key, value) VALUES
  ('feature_flags', jsonb_build_object(
    'ar_enabled', true,
    'ai_builder_enabled', true,
    'community_enabled', true,
    'push_notifications_enabled', true,
    'offline_sync_enabled', true
  )),
  ('xp_rewards', jsonb_build_object(
    'post_created', 50,
    'post_liked', 5,
    'comment_posted', 10,
    'build_session_per_5min', 1,
    'achievement_earned', 100,
    'follower_gained', 20
  )),
  ('limits', jsonb_build_object(
    'max_inventory_items', 10000,
    'max_collections', 100,
    'max_ai_builds_saved', 500,
    'max_image_size_mb', 50,
    'max_video_size_mb', 100
  )),
  ('backup', jsonb_build_object(
    'auto_backup_enabled', true,
    'backup_frequency_days', 7,
    'retention_days', 90
  ))
ON CONFLICT (key) DO NOTHING;
