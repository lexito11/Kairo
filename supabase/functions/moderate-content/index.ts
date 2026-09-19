import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const VISION_PROVIDER = (Deno.env.get("KAIRO_VISION_PROVIDER") ?? "none").toLowerCase();
const VISION_KEY = Deno.env.get("KAIRO_VISION_API_KEY") ?? "";
const VISION_USER = Deno.env.get("KAIRO_VISION_API_USER") ?? "";
const VISION_SECRET = Deno.env.get("KAIRO_VISION_API_SECRET") ?? "";
const JOB_SECRET = Deno.env.get("KAIRO_JOB_SECRET") ?? "";

type QueueRow = {
  id: string;
  content_type: string;
  content_id: string;
  user_id: string | null;
  media_ref: string | null;
  media_type: string | null;
  text_blob: string | null;
  attempts: number;
};

type VisionVerdict = {
  action: "approved" | "confirmed" | "flagged";
  category?: string;
  reason?: string;
  notes: string;
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("missing_supabase_env");
  return createClient(url, key, { auth: { persistSession: false } });
}

function mediaUrls(ref: string | null): string[] {
  if (!ref) return [];
  try {
    const parsed = JSON.parse(ref);
    if (Array.isArray(parsed)) return parsed.filter((u) => typeof u === "string");
  } catch {
    // single URL
  }
  return [ref];
}

function isVideo(mediaType: string | null, url: string) {
  return (mediaType ?? "").startsWith("video") || /\.(mp4|mov|webm)(\?|$)/i.test(url);
}

async function sightengineCheck(url: string, video: boolean): Promise<VisionVerdict> {
  const user = VISION_USER || VISION_KEY;
  const secret = VISION_SECRET;
  if (!user || !secret) {
    return {
      action: "flagged",
      notes: "vision_provider=sightengine; missing KAIRO_VISION_API_USER/SECRET",
    };
  }

  const endpoint = video
    ? "https://api.sightengine.com/1.0/video/check-sync.json"
    : "https://api.sightengine.com/1.0/check.json";
  const params = new URLSearchParams({
    api_user: user,
    api_secret: secret,
    models: "nudity-2.0,offensive",
  });
  if (video) params.set("stream_url", url);
  else params.set("url", url);

  const res = await fetch(`${endpoint}?${params.toString()}`);
  const payload = await res.json();
  if (!res.ok) {
    return {
      action: "flagged",
      notes: `sightengine_http_${res.status}; ${JSON.stringify(payload).slice(0, 400)}`,
    };
  }

  const nudity = payload.nudity ?? {};
  const sexualActivity = Number(nudity.sexual_activity ?? 0);
  const sexualDisplay = Number(nudity.sexual_display ?? 0);
  const erotica = Number(nudity.erotica ?? 0);
  const verySuggestive = Number(nudity.very_suggestive ?? 0);
  const underwear = Number(nudity.underwear ?? nudity.lingerie ?? 0);
  const bikini = Number(nudity.bikini ?? nudity.swimwear ?? 0);

  const notes = video
    ? `provider=sightengine; mode=video_url_sample; not_full_video_audit; activity=${sexualActivity}; display=${sexualDisplay}; erotica=${erotica}`
    : `provider=sightengine; mode=image_url; activity=${sexualActivity}; display=${sexualDisplay}; erotica=${erotica}; bikini=${bikini}; underwear=${underwear}`;

  if (sexualActivity >= 0.45 || sexualDisplay >= 0.45 || erotica >= 0.55) {
    return { action: "confirmed", category: "sexual", reason: "explicit_or_nude", notes };
  }
  if (bikini >= 0.55) {
    return { action: "confirmed", category: "bikini", reason: "bikini", notes };
  }
  if (underwear >= 0.55) {
    return { action: "confirmed", category: "underwear", reason: "underwear", notes };
  }
  if (verySuggestive >= 0.8) {
    return { action: "flagged", category: "sexual", reason: "very_suggestive", notes };
  }
  return { action: "approved", notes };
}

async function openaiCheck(url: string, video: boolean): Promise<VisionVerdict> {
  if (video) {
    return {
      action: "flagged",
      notes: "provider=openai; mode=no_frame_extraction; video_not_fully_scanned",
    };
  }
  if (!VISION_KEY) {
    return { action: "flagged", notes: "vision_provider=openai; missing KAIRO_VISION_API_KEY" };
  }

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${VISION_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "Classify whether an image violates a Christian community policy. Return JSON {allowed:boolean, category:string, reason:string, confidence:number}. Categories: sexual, nudity, bikini, underwear, sexualPromotion, none. allowed=false only for explicit sexual content, nudity, bikini, underwear, or sexual advertising.",
        },
        {
          role: "user",
          content: [
            { type: "text", text: "Classify this image." },
            { type: "image_url", image_url: { url } },
          ],
        },
      ],
    }),
  });
  const payload = await res.json();
  if (!res.ok) {
    return {
      action: "flagged",
      notes: `openai_http_${res.status}; ${JSON.stringify(payload).slice(0, 400)}`,
    };
  }
  let parsed: { allowed?: boolean; category?: string; reason?: string; confidence?: number } = {};
  try {
    parsed = JSON.parse(payload.choices?.[0]?.message?.content ?? "{}");
  } catch {
    return { action: "flagged", notes: "provider=openai; unparseable_response" };
  }
  const notes = `provider=openai; mode=single_image; confidence=${parsed.confidence ?? "n/a"}`;
  if (parsed.allowed === false && (parsed.confidence ?? 0) >= 0.7) {
    return {
      action: "confirmed",
      category: parsed.category ?? "sexual",
      reason: parsed.reason ?? "vision_confirmed",
      notes,
    };
  }
  if (parsed.allowed === false) {
    return {
      action: "flagged",
      category: parsed.category,
      reason: parsed.reason,
      notes,
    };
  }
  return { action: "approved", notes };
}

async function analyzeMedia(row: QueueRow): Promise<VisionVerdict> {
  const urls = mediaUrls(row.media_ref);
  if (urls.length === 0) {
    return { action: "approved", notes: "no_media_url" };
  }

  if (VISION_PROVIDER === "none" || VISION_PROVIDER === "") {
    return {
      action: "flagged",
      notes: "no_vision_provider; set KAIRO_VISION_PROVIDER=sightengine|openai",
    };
  }

  const verdicts: VisionVerdict[] = [];
  for (const url of urls) {
    const video = isVideo(row.media_type, url);
    if (VISION_PROVIDER === "sightengine") {
      verdicts.push(await sightengineCheck(url, video));
    } else if (VISION_PROVIDER === "openai") {
      verdicts.push(await openaiCheck(url, video));
    } else {
      verdicts.push({
        action: "flagged",
        notes: `unknown_provider=${VISION_PROVIDER}`,
      });
    }
  }

  const confirmed = verdicts.find((v) => v.action === "confirmed");
  if (confirmed) return confirmed;
  const flagged = verdicts.find((v) => v.action === "flagged");
  if (flagged) {
    return {
      ...flagged,
      notes: verdicts.map((v) => v.notes).join(" | "),
    };
  }
  return {
    action: "approved",
    notes: verdicts.map((v) => v.notes).join(" | "),
  };
}

async function processQueue(supabase: ReturnType<typeof serviceClient>) {
  await supabase.rpc("process_moderation_text_batch", { p_limit: 25 });
  const { data, error } = await supabase.rpc("claim_moderation_media_batch", { p_limit: 6 });
  if (error) throw error;
  const rows = (data ?? []) as QueueRow[];
  const results = [];
  for (const row of rows) {
    try {
      const verdict = await analyzeMedia(row);
      const { error: doneError } = await supabase.rpc("complete_moderation_job", {
        p_queue_id: row.id,
        p_status: verdict.action,
        p_category: verdict.category ?? null,
        p_reason: verdict.reason ?? null,
        p_notes: verdict.notes,
        p_error: null,
      });
      if (doneError) throw doneError;
      results.push({ id: row.id, status: verdict.action });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await supabase.rpc("complete_moderation_job", {
        p_queue_id: row.id,
        p_status: row.attempts >= 4 ? "flagged" : "pending",
        p_notes: "processor_error",
        p_error: message,
      });
      results.push({ id: row.id, status: "error", error: message });
    }
  }
  return results;
}

async function flushEmail(supabase: ReturnType<typeof serviceClient>) {
  const { data, error } = await supabase.rpc("list_pending_admin_emails");
  if (error) throw error;
  const rows = (data ?? []) as Array<{
    id: string;
    to_email: string;
    subject: string;
    body: string;
    status: string;
  }>;
  const out = [];
  for (const row of rows) {
    try {
      const res = await fetch(`https://formsubmit.co/ajax/${row.to_email}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          name: "KAIRO",
          _subject: row.subject,
          _captcha: "false",
          mensaje: row.body,
        }),
      });
      const httpStatus = res.status;
      if (httpStatus >= 200 && httpStatus < 300) {
        await supabase.rpc("kairo_mark_admin_email", {
          p_outbox_id: row.id,
          p_status: "sent",
          p_http_status: httpStatus,
          p_error: null,
        });
        out.push({ id: row.id, status: "sent", httpStatus });
      } else {
        const text = await res.text();
        await supabase.rpc("kairo_mark_admin_email", {
          p_outbox_id: row.id,
          p_status: "failed",
          p_http_status: httpStatus,
          p_error: text.slice(0, 500),
        });
        out.push({ id: row.id, status: "failed", httpStatus });
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await supabase.rpc("kairo_mark_admin_email", {
        p_outbox_id: row.id,
        p_status: "failed",
        p_error: message,
      });
      out.push({ id: row.id, status: "failed", error: message });
    }
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok");
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (JOB_SECRET) {
    const provided = req.headers.get("x-kairo-job-secret") ?? "";
    if (provided !== JOB_SECRET) return json({ error: "unauthorized" }, 401);
  }

  try {
    const supabase = serviceClient();
    const body = await req.json().catch(() => ({}));
    const action = body.action === "flush_email" ? "flush_email" : "process";
    if (action === "flush_email") {
      return json({ emails: await flushEmail(supabase) });
    }
    const queue = await processQueue(supabase);
    const emails = await flushEmail(supabase);
    return json({ queue, emails });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
