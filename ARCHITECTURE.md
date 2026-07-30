# BuildVerse — Complete Supabase Backend Architecture

## Overview

BuildVerse uses **Supabase** as its complete backend platform, providing:
- PostgreSQL database with Row Level Security
- Supabase Auth (email + Google OAuth)
- Supabase Storage (4 buckets)
- Supabase Realtime (WebSocket subscriptions)
- Edge Functions (Deno serverless)
- Offline sync queue
- Push notification delivery

---

## Database Schema

### Tables

| Table | Description | RLS |
|---|---|---|
| `user_profiles` | Extended user data, XP, streaks, stats | ✅ Owner + public read |
| `inventory_items` | LEGO brick inventory per user | ✅ Owner only |
| `ai_builds` | AI-generated build plans | ✅ Owner only |
| `posts` | Community posts (project/image/video/instructions) | ✅ Public read, owner write |
| `post_likes` | Post like junction | ✅ Public read, owner write |
| `post_bookmarks` | Post bookmark junction | ✅ Owner only |
| `follows` | User follow relationships | ✅ Public read, owner write |
| `uploads` | File upload metadata | ✅ Owner only |
| `collections` | User-curated collections | ✅ Public read (if public), owner write |
| `achievements` | Earned achievements per user | ✅ Public read, owner write |
| `comments` | Threaded post comments | ✅ Public read, owner write |
| `comment_likes` | Comment like junction | ✅ Public read, owner write |
| `notifications` | In-app notifications | ✅ Owner only |
| `push_tokens` | FCM device tokens | ✅ Owner only |
| `post_remixes` | Remix relationship tracking | ✅ Public read |
| `collection_items` | Posts inside collections | ✅ Public read (if public), owner write |
| `build_sessions` | Active building time tracking | ✅ Owner only |
| `sync_queue` | Offline mutation queue | ✅ Owner only |
| `app_config` | Server-driven feature flags & config | ✅ Public read |

### Custom Types (ENUMs)

| Type | Values |
|---|---|
| `brick_status` | active, warning, inactive |
| `post_type` | project, image, video, instructions |
| `upload_type` | image, video, document, model |
| `notification_type` | like, comment, follow, mention, remix, achievement, system, build_complete |
| `sync_operation` | insert, update, delete |

### Database Relationships

```
auth.users
  └── user_profiles (1:1, trigger-created)
        ├── inventory_items (1:N)
        ├── ai_builds (1:N)
        │     └── build_sessions (1:N)
        ├── posts (1:N)
        │     ├── post_likes (N:M via junction)
        │     ├── post_bookmarks (N:M via junction)
        │     ├── comments (1:N, threaded via parent_id)
        │     │     └── comment_likes (N:M via junction)
        │     ├── post_remixes (self-referential N:M)
        │     └── uploads (1:N)
        ├── collections (1:N)
        │     └── collection_items (N:M with posts)
        ├── achievements (1:N)
        ├── follows (N:M self-referential)
        ├── notifications (1:N)
        ├── push_tokens (1:N)
        └── sync_queue (1:N)
```

---

## Storage Buckets

| Bucket | Visibility | Max Size | Allowed Types |
|---|---|---|---|
| `avatars` | **Public** | 5 MB | JPEG, PNG, WebP, GIF |
| `post-media` | **Public** | 50 MB | JPEG, PNG, WebP, GIF, MP4, WebM |
| `build-models` | **Private** | 100 MB | GLTF, GLB, binary |
| `documents` | **Private** | 10 MB | PDF, TXT, JSON |

All buckets enforce folder-based RLS: `{user_id}/filename` — only the owner can write to their folder.

---

## Postgres Indexes

### Performance-Critical Indexes

| Table | Index | Purpose |
|---|---|---|
| `user_profiles` | `idx_user_profiles_xp_desc` | Leaderboard queries |
| `user_profiles` | `idx_user_profiles_username` | Username lookup |
| `posts` | `idx_posts_likes_count` | Trending feed |
| `posts` | `idx_posts_tags_gin` | Tag search (GIN) |
| `post_likes` | `idx_post_likes_unique` | Unique constraint + fast lookup |
| `post_bookmarks` | `idx_post_bookmarks_unique` | Unique constraint + fast lookup |
| `follows` | `idx_follows_unique` | Unique constraint |
| `notifications` | `idx_notifications_unread` | Unread badge count |
| `sync_queue` | `idx_sync_queue_user_pending` | Pending sync entries |
| `inventory_items` | `idx_inventory_is_favorite` | Partial index for favorites |

---

## Row Level Security

### Patterns Used

1. **Owner-only**: `user_id = auth.uid()` — inventory, ai_builds, notifications, push_tokens, build_sessions, sync_queue
2. **Public read / owner write**: posts, comments, follows, post_likes, collections (public ones)
3. **Storage folder-based**: `(storage.foldername(name))[1] = auth.uid()::text`
4. **Junction table**: collection_items checks parent collection ownership

### Anti-patterns Avoided
- No recursive RLS (user_profiles uses direct `id = auth.uid()`)
- No JOINs inside policy USING clauses
- No comma-separated operations (separate policies per operation)

---

## Edge Functions

| Function | Trigger | Purpose |
|---|---|---|
| `send-notification` | DB webhook on `notifications` INSERT | Delivers FCM push notifications |
| `process-sync-queue` | Client call on reconnect | Applies offline mutations |
| `backup-user-data` | Client call | Exports full user data as JSON |
| `weekly-reset` | Cron: Monday 00:00 UTC | Resets weekly stats for all users |

### Deploying Edge Functions

```bash
supabase functions deploy send-notification
supabase functions deploy process-sync-queue
supabase functions deploy backup-user-data
supabase functions deploy weekly-reset
```

### Required Edge Function Secrets

```bash
supabase secrets set FCM_SERVER_KEY=your_fcm_server_key
supabase secrets set CRON_SECRET=your_cron_secret
```

---

## Realtime Subscriptions

| Channel | Table | Events | Filter |
|---|---|---|---|
| `user_notifications_{userId}` | notifications | INSERT | user_id = current user |
| `public_feed` | posts | INSERT, UPDATE, DELETE | none |
| `post_comments_{postId}` | comments | INSERT, DELETE | post_id = target post |
| `user_follows_{userId}` | follows | INSERT | following_id = current user |

Managed by `RealtimeService` in `lib/services/realtime_service.dart`.

---

## Offline Sync

`OfflineSyncService` (`lib/services/offline_sync_service.dart`) provides:

- **Local queue**: Mutations stored in `SharedPreferences` when offline
- **Auto-flush**: Automatically processes queue when connectivity returns
- **Retry logic**: Up to 3 retries per entry before permanent failure
- **Status stream**: `syncStatus` stream for UI indicators
- **Manual sync**: `manualSync()` for user-triggered sync

### Supported Tables for Offline Sync
`inventory_items`, `ai_builds`, `posts`, `collections`, `build_sessions`, `post_likes`, `post_bookmarks`, `follows`

---

## Automated Triggers

| Trigger | Table | Event | Action |
|---|---|---|---|
| `on_comment_insert` | comments | INSERT | Increment `posts.comments_count` |
| `on_comment_delete` | comments | DELETE | Decrement `posts.comments_count` |
| `on_remix_insert` | post_remixes | INSERT | Increment `posts.remixes_count` |
| `on_build_session_update` | build_sessions | UPDATE | Update user XP, hours_built, pieces_scanned |
| `on_post_like_notify` | post_likes | INSERT | Create like notification |
| `on_comment_notify` | comments | INSERT | Create comment notification |
| `on_follow_notify` | follows | INSERT | Create follow notification |
| `on_auth_user_created` | auth.users | INSERT | Auto-create user_profiles row |

---

## Backup & Recovery

### Automated Backup
- Supabase Pro includes daily automated backups with 7-day retention
- `app_config.backup` key configures app-level backup preferences

### Manual Backup
Users can export their data via the `backup-user-data` Edge Function:
```dart
final backup = await SupabaseService.instance.exportUserBackup();
// Returns: profile, inventory, ai_builds, collections, achievements
```

### Backup Contents
```json
{
  "version": "1.0",
  "app": "BuildVerse",
  "user_id": "...",
  "profile": { ... },
  "inventory": [ ... ],
  "ai_builds": [ ... ],
  "collections": [ ... ],
  "achievements": [ ... ],
  "exported_at": "2026-07-30T12:22:48Z"
}
```

---

## App Config (Server-Driven)

Stored in `app_config` table, readable by all clients:

| Key | Purpose |
|---|---|
| `feature_flags` | Toggle features: AR, AI builder, community, push notifications, offline sync |
| `xp_rewards` | XP values for each action type |
| `limits` | Max inventory items, collections, AI builds, file sizes |
| `backup` | Auto-backup frequency and retention settings |

---

## Flutter Services

| Service | File | Purpose |
|---|---|---|
| `SupabaseService` | `lib/services/supabase_service.dart` | All DB + Storage + Edge Function calls |
| `OfflineSyncService` | `lib/services/offline_sync_service.dart` | Offline queue management |
| `RealtimeService` | `lib/services/realtime_service.dart` | WebSocket channel management |

---

## Migration Files

| File | Description |
|---|---|
| `20260730115435_buildverse_schema.sql` | Core schema: user_profiles, inventory, ai_builds, posts, likes, bookmarks, follows, uploads |
| `20260730121039_buildverse_profile_extended.sql` | Extended profile: collections, achievements, 15 new profile columns |
| `20260730122248_buildverse_full_architecture.sql` | Full architecture: storage buckets, comments, notifications, push_tokens, remixes, collection_items, build_sessions, sync_queue, app_config, 40+ indexes, triggers, RLS, realtime |
