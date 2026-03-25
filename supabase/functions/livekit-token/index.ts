import { AccessToken } from "npm:livekit-server-sdk@2.14.0";
import { createClient } from "npm:@supabase/supabase-js@2.49.8";

type TokenRequestBody = {
  roomId?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY");
  const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET");
  const livekitUrl = Deno.env.get("LIVEKIT_URL");

  if (!supabaseURL || !serviceRoleKey || !livekitApiKey || !livekitApiSecret || !livekitUrl) {
    return json(500, { error: "Missing function secrets" });
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return json(401, { error: "Missing Authorization header" });
  }

  const body = (await request.json().catch(() => ({}))) as TokenRequestBody;
  const roomId = body.roomId;
  if (!roomId) {
    return json(400, { error: "roomId is required" });
  }

  // Normalize headers like "Bearer <jwt>" and accidental "Bearer Bearer <jwt>".
  let jwt = authHeader.trim();
  while (/^Bearer\s+/i.test(jwt)) {
    jwt = jwt.replace(/^Bearer\s+/i, "").trim();
  }
  if (!jwt) {
    return json(401, { error: "Invalid Authorization header" });
  }

  const supabaseAdmin = createClient(supabaseURL, serviceRoleKey);

  const {
    data: { user },
    error: userError,
  } = await supabaseAdmin.auth.getUser(jwt);

  if (userError || !user) {
    return json(401, { error: "Invalid auth session" });
  }

  const { data: member, error: memberError } = await supabaseAdmin
    .from("room_members")
    .select("room_id")
    .eq("room_id", roomId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (memberError) {
    return json(500, { error: "Failed membership check", details: memberError.message });
  }

  if (!member) {
    return json(403, { error: "Forbidden" });
  }

  const participantIdentity = user.id;
  const participantName = user.email ?? "participant";
  const roomName = roomId;

  const token = new AccessToken(livekitApiKey, livekitApiSecret, {
    identity: participantIdentity,
    name: participantName,
    ttl: "20m",
  });

  token.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  const livekitJwt = await token.toJwt();

  return json(200, {
    token: livekitJwt,
    livekitUrl,
    roomName,
    identity: participantIdentity,
  });
});
