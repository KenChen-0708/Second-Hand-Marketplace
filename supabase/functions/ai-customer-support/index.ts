import { createClient } from "https://esm.sh/@supabase/supabase-js@2.50.0";

type SupportMessage = {
  role?: string;
  content?: string;
};

type SupportRequest = {
  message?: string;
  messages?: SupportMessage[];
  user?: {
    id?: string;
    name?: string;
    role?: string;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
const geminiBaseUrl =
  Deno.env.get("GEMINI_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta";
const geminiModel = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const geminiFallbackModel =
  Deno.env.get("GEMINI_FALLBACK_MODEL") ?? "gemini-2.5-flash-lite";

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("Missing Supabase configuration.");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header." }, 401);
    }

    const [scheme, token] = authHeader.split(" ");
    if (scheme !== "Bearer" || !token) {
      return jsonResponse({ error: "Invalid authorization header." }, 401);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const { data: authData, error: authError } = await supabase.auth.getClaims(token);
    if (authError || !authData?.claims) {
      return jsonResponse({ error: "Unauthorized." }, 401);
    }

    const body = (await request.json()) as SupportRequest;
    const currentMessage = body.message?.trim() ?? "";

    if (!currentMessage) {
      return jsonResponse({ error: "message is required." }, 400);
    }

    if (!geminiApiKey) {
      return jsonResponse(
        { error: "GEMINI_API_KEY is not configured for ai-customer-support." },
        503,
      );
    }

    const recentMessages = (body.messages ?? [])
      .filter((message) => message.content?.trim())
      .slice(-12)
      .map((message) => ({
        role: message.role === "assistant" ? "assistant" : "user",
        content: message.content?.trim() ?? "",
      }));

    const userName = body.user?.name?.trim() || "the user";
    const userRole = body.user?.role?.trim() || "buyer";

    const requestBody = {
      systemInstruction: {
        parts: [
          {
            text:
              "You are CampusSell Support, an AI customer support assistant for a second-hand marketplace app. Give concise, practical help about orders, refunds, disputes, listings, payments, handovers, chat, notifications, seller onboarding, and account settings. Never invent order-specific facts. If account-specific action is needed, tell the user where in the app to go and what to check. If the situation suggests fraud, safety risk, or item not received, advise using the app's dispute or reporting flow. Reply as JSON with this exact shape: {\"reply\":\"...\",\"suggestions\":[\"...\"]}. Suggestions must contain 2 to 4 short follow-up prompts.",
          },
          {
            text: `Current user name: ${userName}. Current user role: ${userRole}.`,
          },
        ],
      },
      generationConfig: {
        temperature: 0.4,
        responseMimeType: "application/json",
      },
      contents: [
        ...recentMessages.map((message) => ({
          role: message.role === "assistant" ? "model" : "user",
          parts: [{ text: message.content }],
        })),
        {
          role: "user",
          parts: [{ text: currentMessage }],
        },
      ],
    };

    let aiResponse = await fetch(
      `${geminiBaseUrl}/models/${geminiModel}:generateContent?key=${encodeURIComponent(geminiApiKey)}`,
      {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    },
    );

    if (!aiResponse.ok) {
      const primaryErrorText = await aiResponse.text();
      const shouldTryFallback =
        aiResponse.status == 503 && geminiFallbackModel.isNotEmpty &&
        geminiFallbackModel != geminiModel;

      if (shouldTryFallback) {
        aiResponse = await fetch(
          `${geminiBaseUrl}/models/${geminiFallbackModel}:generateContent?key=${encodeURIComponent(geminiApiKey)}`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify(requestBody),
          },
        );

        if (!aiResponse.ok) {
          const fallbackErrorText = await aiResponse.text();
          throw new Error(
            `AI provider error: primary ${geminiModel} -> ${primaryErrorText}; fallback ${geminiFallbackModel} -> ${fallbackErrorText}`,
          );
        }
      } else {
        throw new Error(`AI provider error: ${primaryErrorText}`);
      }
    }

    const aiJson = await aiResponse.json();
    const content =
      aiJson?.candidates?.[0]?.content?.parts?.[0]?.text?.toString() ?? "";
    if (!content) {
      throw new Error("AI provider returned an empty reply.");
    }

    const parsed = JSON.parse(content) as {
      reply?: string;
      suggestions?: string[];
    };

    return jsonResponse({
      reply: parsed.reply?.trim() ?? "",
      suggestions: (parsed.suggestions ?? [])
        .map((item) => item.toString().trim())
        .filter(Boolean)
        .slice(0, 4),
      source: "gemini",
    });
  } catch (error) {
    console.error("ai-customer-support failed", error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error." },
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
