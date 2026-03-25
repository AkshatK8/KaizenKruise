import { createClient } from "npm:@supabase/supabase-js@2.49.8";

type JoinRoomBody = {
  code?: string;
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
  if (!supabaseURL || !serviceRoleKey) {
    return json(500, { error: "Missing function secrets" });
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return json(401, { error: "Missing Authorization header" });
  }

  const body = (await request.json().catch(() => ({}))) as JoinRoomBody;
  const rawCode = body.code ?? "";
  const code = rawCode.replace(/\D/g, "");

  if (code.length !== 4) {
    return json(400, { error: "code must be exactly 4 digits" });
  }

  const supabase = createClient(supabaseURL, serviceRoleKey, {
    global: {
      headers: { Authorization: authHeader },
    },
  });

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return json(401, { error: "Invalid auth session" });
  }

  const { data, error } = await supabase.rpc("join_room_by_code", {
    input_code: code,
  });

  if (error) {
    return json(400, { error: error.message });
  }

  return json(200, {
    room: data,
  });
});
