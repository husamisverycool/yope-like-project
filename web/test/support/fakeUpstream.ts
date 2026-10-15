// In-memory stand-in for Supabase (unit tests): previews by token, objects by signed URL.

import type { InvitePreview, PreviewLookup, Upstream } from "../../src/supabase.js";
import { UpstreamError } from "../../src/supabase.js";

export class FakeUpstream implements Upstream {
  previews = new Map<string, PreviewLookup>();
  objects = new Map<string, Buffer>();
  calls = { preview: 0, sign: 0, fetch: 0 };
  failPreview = false;
  signed: string[] = [];

  setPreview(token: string, preview: InvitePreview) {
    this.previews.set(token, { status: "ok", preview });
  }

  async invitePreview(token: string): Promise<PreviewLookup> {
    this.calls.preview++;
    if (this.failPreview) throw new UpstreamError("down");
    return this.previews.get(token) ?? { status: "not_found" };
  }

  async signPaths(paths: string[]): Promise<Map<string, string>> {
    this.calls.sign++;
    const out = new Map<string, string>();
    for (const p of paths) {
      this.signed.push(p);
      if (this.objects.has(p)) out.set(p, `https://storage.test/sign/${p}?token=t`);
    }
    return out;
  }

  async fetchObject(url: string): Promise<Buffer> {
    this.calls.fetch++;
    const path = url.replace("https://storage.test/sign/", "").replace(/\?token=t$/, "");
    const buf = this.objects.get(path);
    if (!buf) throw new UpstreamError("missing");
    return buf;
  }
}
