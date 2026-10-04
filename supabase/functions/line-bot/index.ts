// LINE Official Account bot for shop alerts (migration 0010).
// - LINE webhook: a shop sends the 6-digit code shown in the app to link their LINE.
// - {"action": "alerts"} from the cron job: sends a LINE message for each order still not accepted after
//   3 minutes. claim_line_alerts hands each order out once, so a stray call sends nothing extra.
//
// Secrets needed (Supabase > Edge Functions > Secrets), from LINE Developers > the channel > Messaging API /
// Basic settings: LINE_CHANNEL_ACCESS_TOKEN and LINE_CHANNEL_SECRET.
// Deploy with "Verify JWT" turned off: LINE and the database call it without a user token.

import { createClient } from "jsr:@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const token = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN") ?? "";
const secret = Deno.env.get("LINE_CHANNEL_SECRET") ?? "";
const appUrl = "https://cozy-melomakarona-cafbc6.netlify.app";

async function line(path: string, body: unknown) {
  const res = await fetch(`https://api.line.me/v2/bot/message/${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) console.error("line", path, res.status, await res.text());
  return res.ok;
}

const text = (t: string) => ({ type: "text", text: t });

// LINE signs each webhook with the channel secret; anything else is ignored.
async function validSignature(raw: string, signature: string | null): Promise<boolean> {
  if (!signature || !secret) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw)));
  let s = "";
  for (const b of mac) s += String.fromCharCode(b);
  return btoa(s) === signature;
}

async function sendAlerts(): Promise<Response> {
  const { data, error } = await db.rpc("claim_line_alerts");
  if (error) throw error;
  let sent = 0;
  for (const r of data ?? []) {
    const when = r.scheduled_for
      ? `ออเดอร์จองล่วงหน้า #${r.short_id} รอร้านกดรับอยู่`
      : `ออเดอร์ #${r.short_id} รอร้านกดรับมา ${r.minutes} นาทีแล้ว`;
    const ok = await line("push", {
      to: r.line_user_id,
      messages: [text(`🔔 ${r.shop_name}\n${when}\nเปิดแอปเพื่อกดรับออเดอร์: ${appUrl}`)],
    });
    if (ok) sent++;
  }
  return new Response(`sent ${sent}`);
}

async function handleWebhook(raw: string): Promise<Response> {
  const { events } = JSON.parse(raw);
  for (const e of events ?? []) {
    const userId = e.source?.userId;
    if (!userId || !e.replyToken) continue;
    if (e.type === "follow") {
      await line("reply", {
        replyToken: e.replyToken,
        messages: [text(
          "ขอบคุณที่เพิ่มเพื่อน ส่งอาหารบ้านดุง\nร้านค้า: เปิดแอป แท็บ \"ตั้งค่าร้าน\" กด \"ผูก LINE\" แล้วส่งรหัส 6 หลักมาในแชตนี้ เพื่อรับแจ้งเตือนออเดอร์ที่ยังไม่กดรับ",
        )],
      });
    } else if (e.type === "message" && e.message?.type === "text") {
      const code = String(e.message.text).replace(/\D/g, "");
      if (code.length !== 6) continue;
      const { data: name, error } = await db.rpc("link_line_user", { p_code: code, p_line_user_id: userId });
      if (error) console.error(error);
      await line("reply", {
        replyToken: e.replyToken,
        messages: [text(
          name === null || error
            ? "รหัสไม่ถูกต้องหรือหมดอายุแล้ว กด \"ผูก LINE\" ในแอปเพื่อขอรหัสใหม่"
            : `ผูก LINE กับบัญชี ${name || "ของคุณ"} เรียบร้อย ✅\nถ้ามีออเดอร์ที่ยังไม่กดรับเกิน 3 นาที จะแจ้งเตือนที่นี่`,
        )],
      });
    }
  }
  return new Response("ok");
}

Deno.serve(async (req) => {
  try {
    const raw = await req.text();
    const signature = req.headers.get("x-line-signature");
    if (signature) {
      if (!(await validSignature(raw, signature))) return new Response("bad signature", { status: 401 });
      return await handleWebhook(raw);
    }
    const body = raw ? JSON.parse(raw) : {};
    if (body.action === "alerts") return await sendAlerts();
    return new Response("ok");
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
