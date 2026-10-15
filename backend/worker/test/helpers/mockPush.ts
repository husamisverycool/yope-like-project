// Local HTTP/2 + TLS (self-signed) stand-ins for APNs and FCM, recording every request.

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import http2 from "node:http2";
import os from "node:os";
import path from "node:path";
import type { AddressInfo } from "node:net";
import { verifyEs256, verifyRs256, decodeJwt } from "../../src/push/jwt.js";

let certs: { key: string; cert: string } | null = null;
export function selfSignedCert(): { key: string; cert: string } {
  if (certs) return certs;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "worker-cert-"));
  execFileSync("openssl", [
    "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes",
    "-keyout", path.join(dir, "key.pem"), "-out", path.join(dir, "cert.pem"), "-days", "2",
    "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
  ], { stdio: "ignore" });
  certs = { key: fs.readFileSync(path.join(dir, "key.pem"), "utf8"), cert: fs.readFileSync(path.join(dir, "cert.pem"), "utf8") };
  fs.rmSync(dir, { recursive: true, force: true });
  return certs;
}

export interface Recorded {
  method: string;
  path: string;
  headers: http2.IncomingHttpHeaders;
  body: string;
  json: any;
  /** process.hrtime in ms when the request headers arrived */
  receivedAt: number;
}

function bodyOf(stream: http2.ServerHttp2Stream): Promise<string> {
  return new Promise((resolve) => {
    const parts: Buffer[] = [];
    stream.on("data", (c: Buffer) => parts.push(c));
    stream.on("end", () => resolve(Buffer.concat(parts).toString("utf8")));
  });
}

const nowMs = () => Number(process.hrtime.bigint() / 1_000_000n);

export interface MockApns {
  origin: string;
  requests: Recorded[];
  publicKey: crypto.KeyObject;
  /** override the response for a device token */
  respond: Map<string, { status: number; reason?: string }>;
  channels: Set<string>;
  close(): Promise<void>;
  reset(): void;
}

export async function startMockApns(opts: { publicKey: crypto.KeyObject; teamId: string; keyId: string; bundleId: string }): Promise<MockApns> {
  const { key, cert } = selfSignedCert();
  const requests: Recorded[] = [];
  const respond = new Map<string, { status: number; reason?: string }>();
  const channels = new Set<string>();
  let channelSeq = 0;
  const server = http2.createSecureServer({ key, cert });
  server.on("stream", async (stream, headers) => {
    const receivedAt = nowMs();
    const p = String(headers[":path"]);
    const method = String(headers[":method"]);
    const body = await bodyOf(stream);
    let json: any = null;
    try {
      json = body ? JSON.parse(body) : null;
    } catch {
      json = null;
    }
    requests.push({ method, path: p, headers, body, json, receivedAt });
    const reply = (status: number, extra: Record<string, string> = {}, payload?: unknown) => {
      stream.respond({ ":status": status, "apns-id": crypto.randomUUID(), ...extra });
      stream.end(payload === undefined ? undefined : JSON.stringify(payload));
    };
    // provider token check (ES256, kid, iss)
    const auth = String(headers.authorization ?? "");
    const jwt = auth.replace(/^bearer /, "");
    try {
      const d = decodeJwt(jwt);
      if (!verifyEs256(jwt, opts.publicKey) || d.header.kid !== opts.keyId || d.claims.iss !== opts.teamId) return reply(403, {}, { reason: "InvalidProviderToken" });
    } catch {
      return reply(403, {}, { reason: "MissingProviderToken" });
    }
    if (p === `/1/apps/${opts.bundleId}/channels` && method === "POST") {
      const id = Buffer.from(`channel-${++channelSeq}`).toString("base64");
      channels.add(id);
      return reply(201, { "apns-channel-id": id });
    }
    if (p === `/1/apps/${opts.bundleId}/channels` && method === "DELETE") {
      const id = String(headers["apns-channel-id"]);
      if (!channels.delete(id)) return reply(404, {}, { reason: "ChannelNotRegistered" });
      return reply(204);
    }
    if (p === `/4/broadcasts/apps/${opts.bundleId}`) {
      if (!channels.has(String(headers["apns-channel-id"]))) return reply(400, {}, { reason: "BadChannelId" });
      return reply(200);
    }
    const m = /^\/3\/device\/([^/]+)$/.exec(p);
    if (!m) return reply(404, {}, { reason: "BadPath" });
    const token = m[1] as string;
    const r = respond.get(token);
    if (r) return reply(r.status, {}, r.reason ? { reason: r.reason } : undefined);
    if (token.startsWith("gone")) return reply(410, {}, { reason: "Unregistered", timestamp: Date.now() });
    if (token.startsWith("bad")) return reply(400, {}, { reason: "BadDeviceToken" });
    return reply(200);
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const port = (server.address() as AddressInfo).port;
  return {
    origin: `https://localhost:${port}`,
    requests,
    publicKey: opts.publicKey,
    respond,
    channels,
    reset: () => {
      requests.length = 0;
      respond.clear();
    },
    close: () => new Promise((r) => server.close(() => r())),
  };
}

export interface MockFcm {
  origin: string;
  tokenUri: string;
  requests: Recorded[];
  tokenRequests: Recorded[];
  messages(): Array<{ token: string; data: Record<string, string>; android: Record<string, unknown>; receivedAt: number }>;
  unregistered: Set<string>;
  close(): Promise<void>;
  reset(): void;
}

export async function startMockFcm(opts: { publicKey: crypto.KeyObject; projectId: string; clientEmail: string }): Promise<MockFcm> {
  const { key, cert } = selfSignedCert();
  const requests: Recorded[] = [];
  const tokenRequests: Recorded[] = [];
  const unregistered = new Set<string>();
  const issued = new Set<string>();
  const server = http2.createSecureServer({ key, cert });
  let port = 0;
  server.on("stream", async (stream, headers) => {
    const receivedAt = nowMs();
    const p = String(headers[":path"]);
    const body = await bodyOf(stream);
    const reply = (status: number, payload: unknown) => {
      stream.respond({ ":status": status, "content-type": "application/json" });
      stream.end(JSON.stringify(payload));
    };
    if (p === "/token") {
      tokenRequests.push({ method: "POST", path: p, headers, body, json: null, receivedAt });
      const form = new URLSearchParams(body);
      const assertion = form.get("assertion") ?? "";
      const d = decodeJwt(assertion);
      if (
        form.get("grant_type") !== "urn:ietf:params:oauth:grant-type:jwt-bearer" ||
        !verifyRs256(assertion, opts.publicKey) ||
        d.claims.iss !== opts.clientEmail ||
        d.claims.aud !== `https://localhost:${port}/token` ||
        d.claims.scope !== "https://www.googleapis.com/auth/firebase.messaging"
      ) {
        return reply(400, { error: "invalid_grant" });
      }
      const tok = `ya29.${crypto.randomUUID()}`;
      issued.add(tok);
      return reply(200, { access_token: tok, expires_in: 3599, token_type: "Bearer" });
    }
    let json: any = null;
    try {
      json = JSON.parse(body);
    } catch {
      json = null;
    }
    requests.push({ method: String(headers[":method"]), path: p, headers, body, json, receivedAt });
    if (p !== `/v1/projects/${opts.projectId}/messages:send`) return reply(404, { error: { code: 404, status: "NOT_FOUND" } });
    const bearer = String(headers.authorization ?? "").replace(/^Bearer /, "");
    if (!issued.has(bearer)) return reply(401, { error: { code: 401, status: "UNAUTHENTICATED" } });
    const token = json?.message?.token as string;
    if (unregistered.has(token) || token?.startsWith("gone")) {
      return reply(404, { error: { code: 404, message: "Requested entity was not found.", status: "NOT_FOUND", details: [{ "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", errorCode: "UNREGISTERED" }] } });
    }
    return reply(200, { name: `projects/${opts.projectId}/messages/${crypto.randomUUID()}` });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  port = (server.address() as AddressInfo).port;
  return {
    origin: `https://localhost:${port}`,
    tokenUri: `https://localhost:${port}/token`,
    requests,
    tokenRequests,
    unregistered,
    messages: () => requests.filter((r) => r.json?.message).map((r) => ({ ...r.json.message, receivedAt: r.receivedAt })),
    reset: () => {
      requests.length = 0;
      tokenRequests.length = 0;
      unregistered.clear();
    },
    close: () => new Promise((r) => server.close(() => r())),
  };
}

export function pushKeys() {
  const ec = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const rsa = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
  return {
    apnsP8: ec.privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    apnsPublic: ec.publicKey,
    fcmPrivate: rsa.privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    fcmPublic: rsa.publicKey,
  };
}
