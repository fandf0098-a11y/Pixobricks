// BuildVerse Edge Function: send-notification
// Triggered by Supabase webhook on notifications INSERT
// Sends FCM push notification to user's registered devices

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NotificationPayload {
  record: {
    id: string;
    user_id: string;
    actor_id: string | null;
    type: string;
    title: string;
    body: string;
    data: Record<string, unknown>;
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload: NotificationPayload = await req.json();
    const notification = payload.record;

    if (!notification?.user_id) {
      return new Response(JSON.stringify({ error: "Missing user_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch active push tokens for the user
    const { data: tokens, error: tokenError } = await supabase
      .from("push_tokens")
      .select("token, platform")
      .eq("user_id", notification.user_id)
      .eq("is_active", true);

    if (tokenError || !tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No active push tokens found", sent: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let sentCount = 0;

    if (fcmServerKey) {
      // Send FCM notification to each token
      for (const { token } of tokens) {
        try {
          const fcmResponse = await fetch(
            "https://fcm.googleapis.com/fcm/send",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `key=${fcmServerKey}`,
              },
              body: JSON.stringify({
                to: token,
                notification: {
                  title: notification.title,
                  body: notification.body,
                  sound: "default",
                },
                data: {
                  notification_id: notification.id,
                  type: notification.type,
                  ...notification.data,
                },
                priority: "high",
              }),
            }
          );

          if (fcmResponse.ok) {
            sentCount++;
          } else {
            // Deactivate invalid tokens
            const fcmResult = await fcmResponse.json();
            if (
              fcmResult.results?.[0]?.error === "NotRegistered" ||
              fcmResult.results?.[0]?.error === "InvalidRegistration"
            ) {
              await supabase
                .from("push_tokens")
                .update({ is_active: false })
                .eq("token", token);
            }
          }
        } catch (_err) {
          // Continue with other tokens
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        notification_id: notification.id,
        tokens_found: tokens.length,
        sent: sentCount,
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
