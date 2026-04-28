/**
 * GET recent rows from `public.wcs_lesson_video_render_jobs` (admin / ops only).
 *
 * Secret: set `WCS_JOB_LIST_SECRET` on the Edge function; caller sends header
 *   `x-wcs-job-list-secret: <same value>`
 * Also send Supabase `apikey` + `Authorization: Bearer` (anon or user JWT) like other Edge invokes.
 */

import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, accept, x-wcs-job-list-secret",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405);
  }

  const expected = Deno.env.get("WCS_JOB_LIST_SECRET")?.trim();
  if (!expected) {
    return json({ error: "WCS_JOB_LIST_SECRET not configured on function" }, 503);
  }
  const sent = req.headers.get("x-wcs-job-list-secret")?.trim();
  if (sent !== expected) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ error: "Missing Supabase env" }, 500);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const limit = Math.min(50, Math.max(1, Number(Deno.env.get("JOB_LIST_LIMIT") ?? "25")));

  const { data, error } = await admin
    .from("wcs_lesson_video_render_jobs")
    .select(
      "id, course_id, module_id, lesson_id, pipeline_mode, provider, status, playback_url, error_message, client_app_version, created_at, generation_prompt_excerpt",
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("wcs-lesson-video-jobs:", error.message);
    return json({ error: error.message }, 500);
  }

  return json({ jobs: data ?? [] }, 200);
});
