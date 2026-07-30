// BuildVerse Edge Function: weekly-reset
// Resets weekly stats for all users
// Scheduled via Supabase cron: every Monday at 00:00 UTC

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

    // Verify cron secret to prevent unauthorized calls
    const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const client = createClient(supabaseUrl, supabaseServiceKey);

    const { error } = await client.rpc("reset_weekly_stats");

    if (error) {
      throw new Error(`Weekly reset failed: ${error.message}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Weekly stats reset completed",
        timestamp: new Date().toISOString(),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
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
