import jsQR from "jsqr";
import sharp, { type OverlayOptions } from "sharp";
import { describe, expect, it } from "vitest";
import { tokens } from "../../src/generated/tokens.js";
import { qrSvg } from "../../src/render/qr.js";

const SIZE = tokens["invite.web.size.qrDesktop"];
const AVATAR = tokens["invite.web.size.avatarDesktop"];
const URL_ = "https://invite.example.com/i/Tok3n_valid-Abcdefghijkl";

/** The page's QR on white with the avatar circle over its centre (as the desktop page draws it), decoded. */
async function decode(withAvatar: boolean, scale = 1): Promise<string | null> {
  const svg = qrSvg(URL_, "qr", SIZE).replace("<svg ", `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE * scale}" height="${SIZE * scale}" style="color:#000" `); // provenance-ok: test fixture colours
  const pad = 20 * scale;
  const layers: OverlayOptions[] = [{ input: Buffer.from(svg), left: pad, top: pad }];
  if (withAvatar) {
    const d = AVATAR * scale;
    const disc = `<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${d}"><circle cx="${d / 2}" cy="${d / 2}" r="${d / 2}" fill="#8a5a3c"/></svg>`; // provenance-ok: test fixture colour
    layers.push({ input: Buffer.from(disc), left: pad + Math.round((SIZE * scale - d) / 2), top: pad + Math.round((SIZE * scale - d) / 2) });
  }
  const side = SIZE * scale + 2 * pad;
  const { data, info } = await sharp({ create: { width: side, height: side, channels: 4, background: "#ffffff" } }) // provenance-ok: test fixture colour
    .composite(layers)
    .raw()
    .toBuffer({ resolveWithObject: true });
  // jsqr is a CommonJS bundle whose module.exports carries the function as `default`.
  return jsQR.default(new Uint8ClampedArray(data), info.width, info.height)?.data ?? null;
}

describe("desktop QR code", () => {
  it("encodes the invite link, and still reads with the avatar over its centre (level H)", async () => {
    expect(await decode(false)).toBe(URL_);
    expect(await decode(true)).toBe(URL_);
    expect(await decode(true, 2)).toBe(URL_);
  });

  it("draws whole-pixel modules centred in the token box", () => {
    const svg = qrSvg(URL_, "qr", SIZE);
    expect(svg).toContain(`viewBox="0 0 ${SIZE} ${SIZE}"`);
    const coords = [...svg.matchAll(/M([0-9]+) ([0-9]+)h([0-9]+)v([0-9]+)/g)].map((m) => m.slice(1).map(Number));
    const k = coords[0]![3]!;
    expect(Number.isInteger(k) && k >= 1).toBe(true);
    const xs = coords.map((c) => c[0]!);
    const left = Math.min(...xs);
    const right = Math.max(...coords.map((c) => c[0]! + c[2]!));
    expect(Math.abs(left - (SIZE - right))).toBeLessThanOrEqual(1);
  });
});
