/**
 * yatty Cloud Functions — a thin, secret-holding proxy to OpenAI.
 *
 * The OpenAI key lives ONLY here, injected at runtime from Google Secret
 * Manager (`firebase functions:secrets:set OPENAI_KEY`). It is never shipped to
 * the browser. The public booking page calls these callable functions; all
 * persistence is done here with the Admin SDK so customers never need write
 * access to Firestore/Storage.
 *
 * Abuse guards (because these are callable without auth — customers have no
 * account): each call must reference a real, recent appointment, and per-
 * appointment usage is capped. For production you should also enable Firebase
 * App Check; see README.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const crypto = require("crypto");
const OpenAI = require("openai");

initializeApp();
const OPENAI_KEY = defineSecret("OPENAI_KEY");

const REGION = "us-central1";
const MAX_CHAT_TURNS = 30; // per appointment
const MAX_GENERATIONS = 6; // per appointment
const APPOINTMENT_MAX_AGE_MS = 6 * 60 * 60 * 1000; // 6h window to design

const SYSTEM_PROMPT = `You are a warm, concise tattoo-studio assistant helping a
client describe the tattoo they want, before their appointment. Ask ONE short
question at a time, working toward a clear picture of: the subject/idea, style
(e.g. fine-line, traditional, blackwork, realism, watercolor), size, placement
on the body, and colour vs black-and-grey. If the client shares reference
images, react to them specifically. Keep replies to 1-3 sentences. Once you have
subject + style + size + placement, tell them you'll create a concept preview
and STOP asking questions.`;

/** Loads + validates the appointment, returns its snapshot. */
async function loadAppointment(db, appointmentId) {
  if (typeof appointmentId !== "string" || !appointmentId) {
    throw new HttpsError("invalid-argument", "Missing appointmentId.");
  }
  const snap = await db.doc(`appointments/${appointmentId}`).get();
  if (!snap.exists) throw new HttpsError("not-found", "Unknown appointment.");
  const created = snap.get("createdAt");
  const createdMs = created && created.toMillis ? created.toMillis() : 0;
  if (createdMs && Date.now() - createdMs > APPOINTMENT_MAX_AGE_MS) {
    throw new HttpsError("failed-precondition", "This booking is no longer open for design chat.");
  }
  return snap;
}

const designRef = (db, id) => db.doc(`appointments/${id}/private/design`);

/** Atomically bump a usage counter and enforce a cap. */
async function bumpUsage(db, id, field, limit) {
  const ref = designRef(db, id);
  await db.runTransaction(async (tx) => {
    const d = await tx.get(ref);
    const used = (d.exists && d.get(field)) || 0;
    if (used >= limit) {
      throw new HttpsError("resource-exhausted", "Usage limit reached for this booking.");
    }
    tx.set(ref, { [field]: used + 1 }, { merge: true });
  });
}

function sanitizeMessages(messages) {
  if (!Array.isArray(messages) || messages.length > 60) {
    throw new HttpsError("invalid-argument", "Bad conversation.");
  }
  return messages.map((m) => ({
    role: m && m.role === "assistant" ? "assistant" : "user",
    text: typeof (m && m.text) === "string" ? m.text.slice(0, 4000) : "",
    images: Array.isArray(m && m.images) ? m.images.slice(0, 4) : [],
  }));
}

/** A user/assistant turn. Returns the assistant's next reply. */
exports.aiChat = onCall(
  { secrets: [OPENAI_KEY], region: REGION, cors: true, timeoutSeconds: 60 },
  async (req) => {
    const db = getFirestore();
    const { appointmentId } = req.data || {};
    const appt = await loadAppointment(db, appointmentId);
    await bumpUsage(db, appointmentId, "chatTurns", MAX_CHAT_TURNS);
    const messages = sanitizeMessages((req.data || {}).messages);

    const openai = new OpenAI({ apiKey: OPENAI_KEY.value() });
    const oa = [{ role: "system", content: SYSTEM_PROMPT }];
    for (const m of messages) {
      if (m.role === "assistant") {
        oa.push({ role: "assistant", content: m.text });
      } else {
        const content = [{ type: "text", text: m.text }];
        for (const img of m.images) {
          if (typeof img === "string" && img.startsWith("data:image")) {
            content.push({ type: "image_url", image_url: { url: img } });
          }
        }
        oa.push({ role: "user", content });
      }
    }

    const resp = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: oa,
      max_tokens: 400,
    });
    const reply = resp.choices?.[0]?.message?.content || "";

    // Persist the running transcript (text only — no image data) so the artist
    // sees the conversation even if the client never generates a concept.
    const transcript = [
      ...messages.map((m) => ({
        role: m.role,
        text: m.text,
        hasImages: (m.images || []).length > 0,
      })),
      { role: "assistant", text: reply, hasImages: false },
    ];
    await designRef(db, appointmentId).set(
      {
        transcript,
        artistId: appt.get("artistId"),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { reply };
  }
);

/**
 * Turns the consultation into (a) a brief for the artist and (b) a generated
 * concept image. Persists everything to appointments/{id}/private/design and
 * uploads the images to Storage. Returns the concept image inline so the client
 * can show it immediately.
 */
exports.aiGenerateConcept = onCall(
  { secrets: [OPENAI_KEY], region: REGION, cors: true, timeoutSeconds: 120, memory: "512MiB" },
  async (req) => {
    const db = getFirestore();
    const { appointmentId } = req.data || {};
    const appt = await loadAppointment(db, appointmentId);
    await bumpUsage(db, appointmentId, "generations", MAX_GENERATIONS);

    const messages = sanitizeMessages((req.data || {}).messages);
    const referenceImages = Array.isArray((req.data || {}).referenceImages)
      ? (req.data || {}).referenceImages.slice(0, 4)
      : [];

    const openai = new OpenAI({ apiKey: OPENAI_KEY.value() });

    // 1) Summarise the chat (+ reference images) into a brief + an image prompt.
    const convo = messages.map((m) => `${m.role}: ${m.text}`).join("\n");
    const userContent = [{ type: "text", text: `Consultation transcript:\n${convo}` }];
    for (const img of referenceImages) {
      if (typeof img === "string" && img.startsWith("data:image")) {
        userContent.push({ type: "image_url", image_url: { url: img } });
      }
    }
    const sum = await openai.chat.completions.create({
      model: "gpt-4o",
      response_format: { type: "json_object" },
      max_tokens: 500,
      messages: [
        {
          role: "system",
          content:
            "Convert this tattoo consultation into strict JSON with keys: " +
            "summary (1-2 sentences for the artist), placement, style, size, " +
            "colors, imagePrompt. imagePrompt must describe a single clean " +
            "tattoo design on a plain white background (just the artwork, no " +
            "body part, no scene), suitable for an image generator.",
        },
        { role: "user", content: userContent },
      ],
    });
    let brief = {};
    try {
      brief = JSON.parse(sum.choices?.[0]?.message?.content || "{}");
    } catch (_) {
      brief = {};
    }
    const imagePrompt =
      (brief.imagePrompt && String(brief.imagePrompt)) ||
      "A clean tattoo design concept on a plain white background.";

    // 2) Generate the concept image.
    const gen = await openai.images.generate({
      model: "gpt-image-1",
      prompt: imagePrompt,
      size: "1024x1024",
    });
    const conceptB64 = gen.data?.[0]?.b64_json;
    if (!conceptB64) throw new HttpsError("internal", "Image generation failed.");

    // 3) Upload concept + reference images to Storage under an unguessable path.
    const bucket = getStorage().bucket();
    const token = crypto.randomBytes(8).toString("hex");
    const conceptPath = `appointments/${appointmentId}/${token}_concept.png`;
    await bucket
      .file(conceptPath)
      .save(Buffer.from(conceptB64, "base64"), { contentType: "image/png", resumable: false });

    const referencePaths = [];
    let i = 0;
    for (const img of referenceImages) {
      const m = /^data:(image\/[a-zA-Z+]+);base64,(.*)$/.exec(img || "");
      if (!m) continue;
      const rp = `appointments/${appointmentId}/${token}_ref${i}.png`;
      await bucket.file(rp).save(Buffer.from(m[2], "base64"), {
        contentType: m[1],
        resumable: false,
      });
      referencePaths.push(rp);
      i++;
    }

    // 4) Persist the brief for the artist (Admin SDK bypasses security rules).
    await designRef(db, appointmentId).set(
      {
        summary: brief.summary || "",
        placement: brief.placement || "",
        style: brief.style || "",
        size: brief.size || "",
        colors: brief.colors || "",
        conceptPath,
        referencePaths,
        transcript: messages.map((m) => ({ role: m.role, text: m.text })),
        artistId: appt.get("artistId"),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      conceptImageBase64: conceptB64,
      summary: brief.summary || "",
      placement: brief.placement || "",
      style: brief.style || "",
      size: brief.size || "",
      colors: brief.colors || "",
    };
  }
);
