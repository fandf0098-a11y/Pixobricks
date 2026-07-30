// BuildVerse Edge Function: process-sync-queue
// Processes pending offline mutations from sync_queue table
// Called by client when connectivity is restored

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Use user's JWT for RLS enforcement
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });

    const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

    // Get current user
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch pending sync entries for this user (max 50 per batch)
    const { data: entries, error: fetchError } = await serviceClient
      .from("sync_queue")
      .select("*")
      .eq("user_id", user.id)
      .eq("is_processed", false)
      .lt("retry_count", 3)
      .order("created_at", { ascending: true })
      .limit(50);

    if (fetchError) {
      throw new Error(`Failed to fetch sync queue: ${fetchError.message}`);
    }

    if (!entries || entries.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed: 0, message: "Queue empty" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results = { processed: 0, failed: 0, errors: [] as string[] };

    const ALLOWED_TABLES = [
      "inventory_items", "ai_builds", "posts", "collections",
      "build_sessions", "post_likes", "post_bookmarks", "follows",
    ];

    for (const entry of entries) {
      try {
        if (!ALLOWED_TABLES.includes(entry.table_name)) {
          throw new Error(`Table ${entry.table_name} not allowed in sync queue`);
        }

        let opError: { message: string } | null = null;

        if (entry.operation === "insert") {
          const { error } = await serviceClient
            .from(entry.table_name)
            .insert({ ...entry.payload, user_id: user.id });
          opError = error;
        } else if (entry.operation === "update" && entry.record_id) {
          const { error } = await serviceClient
            .from(entry.table_name)
            .update(entry.payload)
            .eq("id", entry.record_id)
            .eq("user_id", user.id);
          opError = error;
        } else if (entry.operation === "delete" && entry.record_id) {
          const { error } = await serviceClient
            .from(entry.table_name)
            .delete()
            .eq("id", entry.record_id)
            .eq("user_id", user.id);
          opError = error;
        }

        if (opError) {
          throw new Error(opError.message);
        }

        // Mark as processed
        await serviceClient
          .from("sync_queue")
          .update({ is_processed: true, processed_at: new Date().toISOString() })
          .eq("id", entry.id);

        results.processed++;
      } catch (err) {
        const errMsg = (err as Error).message;
        results.errors.push(`Entry ${entry.id}: ${errMsg}`);
        results.failed++;

        // Increment retry count and store error
        await serviceClient
          .from("sync_queue")
          .update({
            retry_count: (entry.retry_count ?? 0) + 1,
            error_msg: errMsg,
          })
          .eq("id", entry.id);
      }
    }

    return new Response(JSON.stringify({ success: true, ...results }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
