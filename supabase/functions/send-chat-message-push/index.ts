import { createClient } from "https://esm.sh/@supabase/supabase-js@2.50.0";
import { cert, getApps, initializeApp } from "npm:firebase-admin/app";
import { getMessaging } from "npm:firebase-admin/messaging";

type PushRequest = {
  body?: string;
  conversationId?: string;
  orderId?: string;
  title?: string;
  type?: string;
  recipientId?: string;
  senderId?: string;
  senderName?: string;
  productId?: string;
  productTitle?: string;
  preview?: string;
  isImage?: boolean;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

let cachedSupabaseAdmin: ReturnType<typeof createClient> | null = null;

function getSupabaseAdmin() {
  if (cachedSupabaseAdmin != null) {
    return cachedSupabaseAdmin;
  }

  const firebaseServiceAccountJson =
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ??
    Deno.env.get("FCM_SERVICE_ACCOUNT");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!firebaseServiceAccountJson) {
    throw new Error(
      "Missing Firebase service account secret. Set FIREBASE_SERVICE_ACCOUNT_JSON or FCM_SERVICE_ACCOUNT.",
    );
  }

  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing Supabase service role configuration.");
  }

  if (getApps().length === 0) {
    initializeApp({
      credential: cert(JSON.parse(firebaseServiceAccountJson)),
    });
  }

  cachedSupabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  return cachedSupabaseAdmin;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let body: PushRequest = {};
  let supabaseAdmin: ReturnType<typeof createClient>;

  try {
    supabaseAdmin = getSupabaseAdmin();
    body = (await request.json()) as PushRequest;
    const recipientId = body.recipientId?.trim();
    const conversationId = body.conversationId?.trim() ?? "";

    if (!recipientId) {
      return jsonResponse(
        { error: "recipientId is required." },
        400,
      );
    }

    const { data: recipient, error: recipientError } = await supabaseAdmin
      .from("users")
      .select("id, name, push_enabled, fcm_token")
      .eq("id", recipientId)
      .maybeSingle();

    if (recipientError) {
      throw recipientError;
    }

    const token = recipient?.fcm_token?.toString().trim();
    const pushEnabled = recipient?.push_enabled == true;

    if (!pushEnabled || !token) {
      return jsonResponse({
        delivered: false,
        skipped: true,
        reason: "Recipient has push disabled or no FCM token.",
      });
    }

    const senderName = body.senderName?.trim() || "Someone";
    const productTitle = body.productTitle?.trim();
    const preview = body.preview?.trim() || body.body?.trim() ||
      (body.isImage ? "Sent a photo" : "New message");
    const title = body.title?.trim() || (
      productTitle?.isNotEmpty == true
        ? `${senderName} messaged you about ${productTitle}`
        : `${senderName} sent you a message`
    );
    const type = body.type?.trim() || "message";

    await getMessaging().send({
      token,
      notification: {
        title,
        body: preview,
      },
      data: {
        type,
        conversationId,
        recipientId,
        orderId: body.orderId?.toString() ?? "",
        senderId: body.senderId?.toString() ?? "",
        senderName,
        productId: body.productId?.toString() ?? "",
        productTitle: productTitle ?? "",
        preview,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "marketplace_alerts_v3",
          tag: conversationId
            ? `chat-${conversationId}`
            : `${type}-${body.orderId?.toString() ?? body.productId?.toString() ?? recipientId}`,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    return jsonResponse({ delivered: true });
  } catch (error) {
    const errorCode = extractFirebaseErrorCode(error);

    if (errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token") {
      const recipientId = body.recipientId?.trim();
      if (recipientId) {
        await supabaseAdmin
          .from("users")
          .update({ fcm_token: null })
          .eq("id", recipientId);
      }
    }

    console.error("send-chat-message-push failed", error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});

function jsonResponse(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function extractFirebaseErrorCode(error: unknown) {
  if (typeof error === "object" && error !== null && "code" in error) {
    return String(error.code);
  }
  return "";
}
