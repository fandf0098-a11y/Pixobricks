// BuildVerse Edge Function: backup-user-data
// Generates a full JSON backup of the authenticated user's data
// Uses the get_user_backup_snapshot Postgres function

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
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await client.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Call the Postgres backup snapshot function
    const { data: snapshot, error: snapshotError } = await client.rpc(
      "get_user_backup_snapshot",
      { p_user_id: user.id }
    );

    if (snapshotError) {
      throw new Error(`Backup failed: ${snapshotError.message}`);
    }

    const backupData = {
      version: "1.0",
      app: "BuildVerse",
      user_id: user.id,
      email: user.email,
      ...snapshot,
    };

    return new Response(JSON.stringify(backupData, null, 2), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Content-Disposition": `attachment; filename="buildverse-backup-${Date.now()}.json"`,
      },
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
