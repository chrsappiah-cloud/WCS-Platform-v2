/**
 * WCS lesson text-to-video — Supabase Edge Function
 *
 * Contract: matches iOS `RemoteLessonTextToVideoRequest` / `RemoteLessonTextToVideoResponse`.
 * Persists each invocation to `public.wcs_lesson_video_render_jobs` (single-region audit; service_role only).
 *
 * Secrets (Dashboard → Edge Functions → Secrets):
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto), SUPABASE_ANON_KEY (auto)
 *   OPENAI_API_KEY          — Sora / Videos API
 *   LUMA_API_KEY            — Dream Machine Ray2
 *   LTX_API_KEY             — LTX-compatible HTTP API
 *   LTX_API_BASE_URL        — e.g. https://api.ltx.video/v1
 *   SVD_WORKER_URL          — Self-hosted worker: POST JSON → { "playbackUrl" | "url" } HTTPS
 *
 * Env (optional):
 *   VIDEO_PROVIDER          — mock | sora | luma | ltx | svd (default: mock). iOS `providerBackendHint` overrides when set.
 *   OPENAI_VIDEO_MODEL      — default sora-2
 *   REQUIRE_AUTH            — true to require valid Supabase JWT (default false for dev)
 *   SORA_POLL_MAX_SECONDS    — default 120 (edge CPU limits apply)
 */

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.1";

// --- Types (mirror Swift `RemoteLessonTextToVideoRequest`) ---

type LessonVideoScenePlan = {
  sceneId: string;
  learningObjective?: string | null;
  narrationText: string;
  visualPrompt: string;
  shotType?: string | null;
  durationSeconds?: number | null;
  onScreenText?: string | null;
  referenceImageURL?: string | null;
  needsDiagram?: boolean | null;
  assessmentCheckpoint?: string | null;
};

type LessonVideoStoryboard = {
  storyboardId: string;
  pipelineVersion: string;
  moduleId?: string | null;
  moduleTitle?: string | null;
  lessonId: string;
  lessonTitle?: string | null;
  scenes: LessonVideoScenePlan[];
  masterVisualPrompt?: string | null;
};

type LessonTextToVideoRequest = {
  courseId: string;
  courseTitle: string;
  moduleId: string;
  moduleTitle: string;
  lessonId: string;
  lessonTitle: string;
  lessonNotes: string;
  targetAudience: string;
  level: string;
  textToVideoPrompt: string;
  sourceReferences: string[];
  providerBackendHint?: string | null;
  clientAppVersion: string;
  storyboard?: LessonVideoStoryboard | null;
  pipelineMode?: string | null;
};

type LessonTextToVideoResponse = {
  playbackURL: string;
  message?: string;
};

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, accept",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function resolveProvider(body: LessonTextToVideoRequest): string {
  const hint = (body.providerBackendHint ?? "").trim().toLowerCase();
  if (["sora", "luma", "ltx", "svd", "mock"].includes(hint)) return hint;
  const env = (Deno.env.get("VIDEO_PROVIDER") ?? "mock").trim().toLowerCase();
  return ["sora", "luma", "ltx", "svd", "mock"].includes(env) ? env : "mock";
}

/** Compose one provider prompt from legacy master text and/or Mootion-style scene list (iOS `scene_orchestration_v1`). */
function buildGenerationPrompt(body: LessonTextToVideoRequest): string {
  const master = (body.textToVideoPrompt ?? "").trim();
  const scenes = body.storyboard?.scenes ?? [];
  if (
    body.pipelineMode === "scene_orchestration_v1" && scenes.length > 0
  ) {
    const sceneBlock = scenes
      .map((s) => {
        const vp = (s.visualPrompt ?? "").trim();
        const nt = (s.narrationText ?? "").trim();
        return `[${s.sceneId}] ${vp}${nt ? ` (narration: ${nt})` : ""}`;
      })
      .join("\n");
    const head = master ||
      (body.storyboard?.masterVisualPrompt ?? "").trim() ||
      `Educational lesson video for "${body.lessonTitle}"`;
    return `${head}\n\nScenes:\n${sceneBlock}`;
  }
  return master;
}

async function persistRenderJob(
  admin: SupabaseClient,
  body: LessonTextToVideoRequest,
  provider: string,
  status: "completed" | "failed",
  playbackURL: string | null,
  errorMessage: string | null,
  generationPrompt: string,
): Promise<void> {
  const row = {
    course_id: body.courseId,
    module_id: body.moduleId,
    lesson_id: body.lessonId,
    pipeline_mode: body.pipelineMode ?? null,
    provider,
    status,
    generation_prompt_excerpt: generationPrompt.slice(0, 8000),
    storyboard_json: body.storyboard ?? null,
    request_json: body as unknown as Record<string, unknown>,
    playback_url: playbackURL,
    error_message: errorMessage,
    client_app_version: body.clientAppVersion,
    updated_at: new Date().toISOString(),
  };
  const { error } = await admin.from("wcs_lesson_video_render_jobs").insert(row);
  if (error) {
    console.error("wcs_lesson_video_render_jobs insert failed:", error.message);
  }
}

async function persistBytes(
  admin: SupabaseClient,
  courseId: string,
  lessonId: string,
  bytes: Uint8Array,
): Promise<string> {
  const path = `courses/${courseId}/lessons/${lessonId}.mp4`;
  const { error: upErr } = await admin.storage.from("lesson-videos").upload(path, bytes, {
    contentType: "video/mp4",
    upsert: true,
  });
  if (upErr) throw new Error(`storage upload: ${upErr.message}`);

  const ttl = Number(Deno.env.get("SIGNED_URL_TTL_SECONDS") ?? "604800"); // 7d
  const { data, error: signErr } = await admin.storage.from("lesson-videos").createSignedUrl(path, ttl);
  if (signErr || !data?.signedUrl) throw new Error(`signed url: ${signErr?.message ?? "empty"}`);
  return data.signedUrl;
}

async function fetchBytesFromUrl(url: string): Promise<Uint8Array> {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`download failed ${r.status}: ${await r.text()}`);
  return new Uint8Array(await r.arrayBuffer());
}

// --- mock: instant public sample (no keys) ---

async function providerMock(): Promise<Uint8Array> {
  const url =
    Deno.env.get("MOCK_VIDEO_SAMPLE_URL") ??
    "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
  return await fetchBytesFromUrl(url);
}

// --- OpenAI Sora (Videos API) ---

async function providerSora(prompt: string): Promise<Uint8Array> {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new Error("OPENAI_API_KEY not set");
  const model = Deno.env.get("OPENAI_VIDEO_MODEL") ?? "sora-2";
  const seconds = Deno.env.get("OPENAI_VIDEO_SECONDS") ?? "8";
  const size = Deno.env.get("OPENAI_VIDEO_SIZE") ?? "1280x720";

  const create = await fetch("https://api.openai.com/v1/videos", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model, prompt, seconds, size }),
  });
  const createText = await create.text();
  if (!create.ok) throw new Error(`OpenAI create video: ${create.status} ${createText}`);
  const job = JSON.parse(createText) as { id: string; status?: string };
  const jobId = job.id;

  const deadline = Date.now() + Number(Deno.env.get("SORA_POLL_MAX_SECONDS") ?? "120") * 1000;
  let completed = false;
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 3000));
    const st = await fetch(`https://api.openai.com/v1/videos/${jobId}`, {
      headers: { Authorization: `Bearer ${key}` },
    });
    const stText = await st.text();
    if (!st.ok) throw new Error(`OpenAI poll: ${st.status} ${stText}`);
    const j = JSON.parse(stText) as { status: string; error?: { message?: string } };
    if (j.status === "completed") {
      completed = true;
      break;
    }
    if (j.status === "failed") throw new Error(`OpenAI failed: ${JSON.stringify(j.error)}`);
  }
  if (!completed) {
    throw new Error(
      "OpenAI video job timed out (edge CPU limits). Lower SORA_POLL_MAX_SECONDS or move to webhook/Batch pipeline.",
    );
  }

  const content = await fetch(`https://api.openai.com/v1/videos/${jobId}/content`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  if (!content.ok) {
    const t = await content.text();
    throw new Error(`OpenAI content: ${content.status} ${t}`);
  }
  return new Uint8Array(await content.arrayBuffer());
}

// --- Luma Dream Machine Ray2 ---

async function providerLuma(prompt: string): Promise<Uint8Array> {
  const key = Deno.env.get("LUMA_API_KEY");
  if (!key) throw new Error("LUMA_API_KEY not set");
  const base = "https://api.lumalabs.ai/dream-machine/v1/generations";
  const create = await fetch(base, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      prompt,
      model: Deno.env.get("LUMA_VIDEO_MODEL") ?? "ray-2",
      resolution: Deno.env.get("LUMA_RESOLUTION") ?? "720p",
      duration: Deno.env.get("LUMA_DURATION") ?? "5s",
    }),
  });
  const ct = await create.text();
  if (!create.ok) throw new Error(`Luma create: ${create.status} ${ct}`);
  const gen = JSON.parse(ct) as { id: string };
  const deadline = Date.now() + Number(Deno.env.get("LUMA_POLL_MAX_SECONDS") ?? "180") * 1000;
  let videoUrl: string | undefined;
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 3000));
    const g = await fetch(`${base}/${gen.id}`, {
      headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
    });
    const gt = await g.text();
    if (!g.ok) throw new Error(`Luma poll: ${g.status} ${gt}`);
    const obj = JSON.parse(gt) as {
      state: string;
      failure_reason?: string;
      assets?: { video?: string | null };
    };
    if (obj.state === "completed") {
      videoUrl = obj.assets?.video ?? undefined;
      break;
    }
    if (obj.state === "failed") throw new Error(`Luma failed: ${obj.failure_reason ?? "unknown"}`);
  }
  if (!videoUrl) throw new Error("Luma generation timed out or missing assets.video");
  return await fetchBytesFromUrl(videoUrl);
}

// --- LTX (configure base to match your Lightricks / partner deployment) ---

async function providerLtx(prompt: string): Promise<Uint8Array> {
  const key = Deno.env.get("LTX_API_KEY");
  const base = (Deno.env.get("LTX_API_BASE_URL") ?? "https://api.ltx.video/v1").replace(/\/$/, "");
  if (!key) throw new Error("LTX_API_KEY not set");
  // Adjust path/body to your provider’s OpenAPI; this matches a generic JSON T2V pattern.
  const path = Deno.env.get("LTX_TEXT_TO_VIDEO_PATH") ?? "/text-to-video";
  const res = await fetch(`${base}${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      Accept: "application/json, video/mp4, application/octet-stream",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      prompt,
      model: Deno.env.get("LTX_MODEL") ?? "ltx-2-3-pro",
      duration: Number(Deno.env.get("LTX_DURATION_SECONDS") ?? "8"),
      resolution: Deno.env.get("LTX_RESOLUTION") ?? "1920x1080",
    }),
  });
  const buf = new Uint8Array(await res.arrayBuffer());
  if (!res.ok) {
    throw new Error(`LTX: ${res.status} ${new TextDecoder().decode(buf)}`);
  }
  const ct = res.headers.get("content-type") ?? "";
  if (ct.includes("video/") || ct.includes("octet-stream")) {
    return buf;
  }
  const j = JSON.parse(new TextDecoder().decode(buf)) as {
    playbackURL?: string;
    url?: string;
    video_url?: string;
  };
  const url = j.playbackURL ?? j.url ?? j.video_url;
  if (!url) throw new Error("LTX JSON missing playbackURL/url/video_url");
  return await fetchBytesFromUrl(url);
}

// --- Self-hosted SVD / worker ---

async function providerSvd(prompt: string, body: LessonTextToVideoRequest): Promise<Uint8Array> {
  const worker = Deno.env.get("SVD_WORKER_URL");
  if (!worker) throw new Error("SVD_WORKER_URL not set");
  const res = await fetch(worker, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json, video/mp4, application/octet-stream",
    },
    body: JSON.stringify({
      prompt,
      courseId: body.courseId,
      lessonId: body.lessonId,
      moduleId: body.moduleId,
    }),
  });
  const buf = new Uint8Array(await res.arrayBuffer());
  if (!res.ok) {
    throw new Error(`SVD worker: ${res.status} ${new TextDecoder().decode(buf)}`);
  }
  const ct = res.headers.get("content-type") ?? "";
  if (ct.includes("video/") || ct.includes("octet-stream")) {
    return buf;
  }
  const j = JSON.parse(new TextDecoder().decode(buf)) as {
    playbackURL?: string;
    url?: string;
    playbackUrl?: string;
  };
  const url = j.playbackURL ?? j.playbackUrl ?? j.url;
  if (!url) throw new Error("SVD worker JSON missing playbackURL/url");
  return await fetchBytesFromUrl(url);
}

async function generateVideoBytes(
  provider: string,
  body: LessonTextToVideoRequest,
  generationPrompt: string,
): Promise<Uint8Array> {
  switch (provider) {
    case "mock":
      return await providerMock();
    case "sora":
      return await providerSora(generationPrompt);
    case "luma":
      return await providerLuma(generationPrompt);
    case "ltx":
      return await providerLtx(generationPrompt);
    case "svd":
      return await providerSvd(generationPrompt, body);
    default:
      return await providerMock();
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "Missing Supabase env" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey ?? serviceKey, {
      global: { headers: { Authorization: authHeader } },
    });

    if ((Deno.env.get("REQUIRE_AUTH") ?? "").toLowerCase() === "true") {
      const { data: { user }, error } = await userClient.auth.getUser();
      if (error || !user) {
        return json({ error: "Unauthorized" }, 401);
      }
    }

    const body = (await req.json()) as LessonTextToVideoRequest;
    const hasMasterPrompt = !!(body?.textToVideoPrompt?.trim());
    const sceneCount = body?.storyboard?.scenes?.length ?? 0;
    const hasStoryboard =
      body?.pipelineMode === "scene_orchestration_v1" &&
      Array.isArray(body?.storyboard?.scenes) &&
      sceneCount > 0;
    if (!body?.courseId || !body?.lessonId || (!hasMasterPrompt && !hasStoryboard)) {
      return json(
        {
          error:
            "Invalid body: need courseId, lessonId, and either textToVideoPrompt or scene_orchestration_v1 storyboard.scenes",
        },
        400,
      );
    }

    const provider = resolveProvider(body);
    const admin = createClient(supabaseUrl, serviceKey);
    const generationPrompt = buildGenerationPrompt(body);

    try {
      const bytes = await generateVideoBytes(provider, body, generationPrompt);
      const playbackURL = await persistBytes(admin, body.courseId, body.lessonId, bytes);
      await persistRenderJob(
        admin,
        body,
        provider,
        "completed",
        playbackURL,
        null,
        generationPrompt,
      );
      const out: LessonTextToVideoResponse = {
        playbackURL,
        message: `provider=${provider} client=${body.clientAppVersion} lesson=${body.lessonTitle}`,
      };
      return json(out, 200);
    } catch (genErr) {
      const msg = genErr instanceof Error ? genErr.message : String(genErr);
      await persistRenderJob(
        admin,
        body,
        provider,
        "failed",
        null,
        msg,
        generationPrompt,
      );
      throw genErr;
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("wcs-lesson-text-to-video error:", msg);
    return json({ error: msg }, 502);
  }
});
