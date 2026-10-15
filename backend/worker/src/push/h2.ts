// Minimal HTTP/2 client (node:http2) with one multiplexed session per origin, as APNs requires
// ("Use HTTP/2 and TLS 1.2 or later") and FCM HTTP v1 accepts. Sessions are re-opened after
// GOAWAY / errors.

import http2 from "node:http2";

export interface H2Response {
  status: number;
  headers: http2.IncomingHttpHeaders;
  body: string;
}

export class H2Pool {
  private sessions = new Map<string, http2.ClientHttp2Session>();

  constructor(private readonly opts: { ca?: string | Buffer; timeoutMs?: number } = {}) {}

  private session(origin: string): http2.ClientHttp2Session {
    const existing = this.sessions.get(origin);
    if (existing && !existing.closed && !existing.destroyed) return existing;
    const s = http2.connect(origin, this.opts.ca ? { ca: this.opts.ca } : {});
    const drop = () => {
      if (this.sessions.get(origin) === s) this.sessions.delete(origin);
    };
    s.on("error", drop);
    s.on("goaway", drop);
    s.on("close", drop);
    this.sessions.set(origin, s);
    return s;
  }

  async request(origin: string, headers: http2.OutgoingHttpHeaders, body?: string | Buffer): Promise<H2Response> {
    try {
      return await this.once(origin, headers, body);
    } catch (e) {
      // a session that died between requests: retry once on a fresh one
      const code = (e as { code?: string }).code;
      if (code === "ERR_HTTP2_INVALID_SESSION" || code === "ERR_HTTP2_GOAWAY_SESSION" || code === "ERR_HTTP2_STREAM_CANCEL") {
        this.sessions.get(origin)?.destroy();
        this.sessions.delete(origin);
        return this.once(origin, headers, body);
      }
      throw e;
    }
  }

  private once(origin: string, headers: http2.OutgoingHttpHeaders, body?: string | Buffer): Promise<H2Response> {
    return new Promise((resolve, reject) => {
      let req: http2.ClientHttp2Stream;
      try {
        req = this.session(origin).request(headers);
      } catch (e) {
        reject(e);
        return;
      }
      const timeout = this.opts.timeoutMs ?? 15_000;
      req.setTimeout(timeout, () => {
        req.close(http2.constants.NGHTTP2_CANCEL);
        reject(Object.assign(new Error(`HTTP/2 request to ${origin} timed out after ${timeout} ms`), { code: "ETIMEDOUT" }));
      });
      let status = 0;
      let resHeaders: http2.IncomingHttpHeaders = {};
      const parts: Buffer[] = [];
      req.on("response", (h) => {
        resHeaders = h;
        status = Number(h[":status"] ?? 0);
      });
      req.on("data", (c: Buffer) => parts.push(c));
      req.on("end", () => resolve({ status, headers: resHeaders, body: Buffer.concat(parts).toString("utf8") }));
      req.on("error", reject);
      req.end(body);
    });
  }

  close(): void {
    for (const s of this.sessions.values()) s.close();
    this.sessions.clear();
  }
}
