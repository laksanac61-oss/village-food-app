// Sends a queued shop notification (new order or payment slip) to the shop owner's phones with
// Firebase Cloud Messaging. Called by the orders trigger in migration 0009 with {"event_id": n}.
// claim_push_event only hands out an event once, so a stray call cannot send anything extra.
//
// Secret needed (Supabase > Edge Functions > Secrets): FCM_SERVICE_ACCOUNT = the whole JSON file from
// Firebase > Project settings > Service accounts > Generate new private key.
// Deploy with "Verify JWT" turned off: the database calls it without a user token.

import { createClient } from "jsr:@supabase/supabase-js@2";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

let cachedToken: { value: string; expires: number } | null = null;

function base64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// An OAuth access token for FCM, made by signing a JWT with the service account key.
async function googleToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expires > now + 60) return cachedToken.value;
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${base64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`google token: ${res.status} ${await res.text()}`);
  const json = await res.json();
  cachedToken = { value: json.access_token, expires: now + json.expires_in };
  return json.access_token;
}

Deno.serve(async (req) => {
  try {
    const { event_id } = await req.json();
    if (!Number.isInteger(event_id)) return new Response("bad event", { status: 400 });
    const { data: rows, error } = await db.rpc("claim_push_event", { p_event_id: event_id });
    if (error) throw error;
    if (!rows?.length) return new Response("nothing to send");

    const sa: ServiceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const access = await googleToken(sa);
    let sent = 0;
    for (const r of rows) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: r.token,
            notification: { title: r.title, body: r.body },
            data: { order_id: r.order_id },
            android: {
              priority: "HIGH",
              notification: { channel_id: "orders", sound: "default" },
            },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else {
        const text = await res.text();
        // the app was uninstalled or the token replaced: forget it
        if (res.status === 404 || text.includes("UNREGISTERED")) {
          await db.rpc("drop_push_token", { p_token: r.token });
        } else {
          console.error("fcm", res.status, text);
        }
      }
    }
    return new Response(`sent ${sent}/${rows.length}`);
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
