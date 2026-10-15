import { afterEach, describe, expect, it, vi } from "vitest";
import { parsePreview, supabaseUpstream, UpstreamError } from "../../src/supabase.js";

const UID = "9f2c1a3e-0b4d-4c5e-8f6a-7b8c9d0e1f2a";

describe("invite_preview parsing", () => {
  it("keeps only the documented preview fields", () => {
    const p = parsePreview({
      group_name: "Lima family",
      group_kind: "family",
      cover_path: `u/${UID}/covers/c.jpg`,
      inviter_first_name: "Ana",
      members: [{ first_name: "Ana", avatar_path: `avatars/${UID}/a.jpg`, user_id: UID, phone: "+1555" }],
      member_count: 3,
      group_id: UID,
    });
    expect(p).toStrictEqual({
      group_name: "Lima family",
      group_kind: "family",
      cover_path: `u/${UID}/covers/c.jpg`,
      inviter_first_name: "Ana",
      members: [{ first_name: "Ana", avatar_path: `avatars/${UID}/a.jpg` }],
    });
  });

  it("never signs paths outside the cover/avatar conventions", () => {
    const p = parsePreview({
      group_name: "g",
      group_kind: "friends",
      cover_path: `g/${UID}/collages/x.jpg`,
      inviter_first_name: null,
      members: [{ first_name: null, avatar_path: `avatars/${UID}/../../u/x.jpg` }, { first_name: "B", avatar_path: "avatars/not-a-uuid/a.jpg" }],
    });
    expect(p.cover_path).toBeNull();
    expect(p.members.map((m) => m.avatar_path)).toEqual([null, null]);
  });

  it("rejects an unexpected shape", () => {
    expect(() => parsePreview([])).toThrow(UpstreamError);
    expect(() => parsePreview({ group_name: 1, group_kind: "x", members: [] })).toThrow(UpstreamError);
    expect(() => parsePreview({ group_name: "a", group_kind: "x", members: [{ first_name: 3 }] })).toThrow(UpstreamError);
  });
});

describe("Supabase calls", () => {
  afterEach(() => vi.unstubAllGlobals());
  const up = supabaseUpstream({ url: "https://sb.test", anonKey: "ANON", serviceRoleKey: "SERVICE", timeoutMs: 1000 });

  function stub(status: number, body: unknown) {
    const calls: { url: string; init: RequestInit }[] = [];
    vi.stubGlobal("fetch", async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    });
    return calls;
  }

  it("calls invite_preview with the anon key only", async () => {
    const calls = stub(200, { group_name: "g", group_kind: "friends", cover_path: null, inviter_first_name: null, members: [] });
    await up.invitePreview("T".repeat(24));
    expect(calls[0]!.url).toBe("https://sb.test/rest/v1/rpc/invite_preview");
    const h = calls[0]!.init.headers as Record<string, string>;
    expect(h.apikey).toBe("ANON");
    expect(h.Authorization).toBe("Bearer ANON");
    expect(JSON.stringify(calls[0]!.init)).not.toContain("SERVICE");
    expect(JSON.parse(calls[0]!.init.body as string)).toEqual({ p_token: "T".repeat(24) });
  });

  it.each([
    [404, "invite_not_found", { status: "not_found" }],
    [410, "invite_expired", { status: "unavailable", reason: "expired" }],
    [410, "invite_revoked", { status: "unavailable", reason: "revoked" }],
  ])("maps HTTP %i %s", async (status, message, expected) => {
    stub(status, { code: `PT${status}`, message });
    expect(await up.invitePreview("x")).toEqual(expected);
  });

  it("treats anything else as an upstream error", async () => {
    stub(500, { message: "boom" });
    await expect(up.invitePreview("x")).rejects.toThrow(UpstreamError);
    vi.stubGlobal("fetch", async () => {
      throw new TypeError("fetch failed");
    });
    await expect(up.invitePreview("x")).rejects.toThrow(UpstreamError);
  });

  it("signs with the service role and only allowed paths", async () => {
    const cover = `u/${UID}/covers/c.jpg`;
    const calls = stub(200, [{ path: cover, signedURL: `/object/sign/media/${cover}?token=abc`, error: null }]);
    const out = await up.signPaths([cover, cover, "g/other/x.jpg"], 120);
    expect(calls[0]!.url).toBe("https://sb.test/storage/v1/object/sign/media");
    expect((calls[0]!.init.headers as Record<string, string>).Authorization).toBe("Bearer SERVICE");
    expect(JSON.parse(calls[0]!.init.body as string)).toEqual({ expiresIn: 120, paths: [cover] });
    expect(out.get(cover)).toBe(`https://sb.test/storage/v1/object/sign/media/${cover}?token=abc`);
  });
});
