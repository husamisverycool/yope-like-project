import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import sharp from "sharp";
import { afterEach, describe, expect, it } from "vitest";
import { MissingTokenError } from "../../src/errors.js";
import { probe, locationTags } from "../../src/media/ffmpeg.js";
import { exifHasGps, imageHasLocation, renderAll, scrubImage, scrubMovieLocation, transcodeVideo } from "../../src/media/renditions.js";
import { setTokenOverrides } from "../../src/tokens.js";
import { renderTribute, tributeTokens } from "../../src/tribute/render.js";
import { TEST_TRIBUTE_TOKENS } from "../helpers/tokens.js";
import { WORKER_ROOT } from "../../src/config.js";
import { testJpeg } from "../helpers/db.js";

afterEach(() => setTokenOverrides(null));

function tmpFile(name: string): string {
  return path.join(fs.mkdtempSync(path.join(os.tmpdir(), "worker-test-")), name);
}

function makeVideo(opts: { seconds: number; location?: string; codec?: string; ext?: string }): Buffer {
  const out = tmpFile(`v.${opts.ext ?? "mov"}`);
  const args = ["-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", `testsrc=size=320x240:rate=30:duration=${opts.seconds}`, "-f", "lavfi", "-i", `sine=frequency=440:duration=${opts.seconds}`, "-c:v", opts.codec ?? "mpeg4", "-c:a", "aac", "-shortest"];
  if (opts.location) args.push("-metadata", `location=${opts.location}`, "-metadata", "com.apple.quicktime.content.identifier=ABC-123", "-movflags", "use_metadata_tags");
  args.push(out);
  execFileSync("ffmpeg", args);
  return fs.readFileSync(out);
}

describe("image renditions", () => {
  it("makes thumb / widget / display at the derived sizes, never enlarged, with no metadata", async () => {
    const big = await testJpeg(3, { width: 3024, height: 4032, gps: true });
    const r = await renderAll(big);
    const meta = async (b: Buffer) => sharp(b).metadata();
    const [t, w, d] = [await meta(r.thumb), await meta(r.widget), await meta(r.display)];
    // 3:4 portrait: "outside" covers the box, "inside" fits in it
    expect([t.width, t.height]).toEqual([510, 680]);
    expect([w.width, w.height]).toEqual([1092, 1456]);
    expect([d.width, d.height]).toEqual([1290, 1720]);
    for (const m of [t, w, d]) {
      expect(m.format).toBe("jpeg");
      expect(m.exif).toBeUndefined();
      expect(m.xmp).toBeUndefined();
      expect(m.icc).toBeUndefined();
    }
    const small = await renderAll(await testJpeg(4, { width: 300, height: 400 }));
    expect((await sharp(small.display).metadata()).width).toBe(300);
  });

  it("detects GPS EXIF and scrubs it in a full-resolution copy", async () => {
    const withGps = await testJpeg(5, { gps: true });
    expect(exifHasGps((await sharp(withGps).metadata()).exif)).toBe(true);
    expect(await imageHasLocation(withGps)).toBe(true);
    expect(await imageHasLocation(await testJpeg(5))).toBe(false);
    const clean = await scrubImage(withGps);
    const m = await sharp(clean).metadata();
    expect(m.exif).toBeUndefined();
    expect([m.width, m.height]).toEqual([600, 800]);
  });
});

describe("video", () => {
  it("transcodes to H.264/AAC MP4 without metadata and takes the first frame as poster", async () => {
    const src = makeVideo({ seconds: 1, location: "+48.8566+002.3522/" });
    const v = await transcodeVideo(src, "original.mov");
    const f = tmpFile("out.mp4");
    fs.writeFileSync(f, v.mp4);
    const p = await probe(f);
    expect(p.streams.find((s) => s.codec_type === "video")?.codec_name).toBe("h264");
    expect(p.streams.find((s) => s.codec_type === "audio")?.codec_name).toBe("aac");
    expect(locationTags(p)).toEqual([]);
    expect((await sharp(v.poster).metadata()).width).toBe(320);
    expect(v.cpuSeconds).toBeGreaterThan(0);
  });

  it("short videos: the stored video is cut to video_max_ms and reports its real length", async () => {
    const long = await transcodeVideo(makeVideo({ seconds: 12 }), "original.mov", 10000);
    expect(long.inputMs).toBeGreaterThanOrEqual(11900);
    expect(long.durationMs).toBeGreaterThanOrEqual(9900);
    expect(long.durationMs).toBeLessThanOrEqual(10100);
    const short = await transcodeVideo(makeVideo({ seconds: 2 }), "original.mov", 10000);
    expect(short.durationMs).toBeGreaterThanOrEqual(1900);
    expect(short.durationMs).toBeLessThanOrEqual(2100);
  });

  it("Live Photo movie: kept as is without location; with a location key, remuxed without it", async () => {
    expect(await scrubMovieLocation(makeVideo({ seconds: 1, codec: "libx264" }))).toBeNull();
    const located = makeVideo({ seconds: 1, codec: "libx264", location: "+48.8566+002.3522/" });
    const before = tmpFile("in.mov");
    fs.writeFileSync(before, located);
    expect(locationTags(await probe(before)).length).toBeGreaterThan(0);
    const r = await scrubMovieLocation(located);
    expect(r).not.toBeNull();
    const after = tmpFile("out.mov");
    fs.writeFileSync(after, r!.data);
    const p = await probe(after);
    expect(locationTags(p)).toEqual([]);
    expect(p.streams.find((s) => s.codec_type === "video")?.codec_name).toBe("h264"); // not re-encoded
    expect(p.format.tags?.["com.apple.quicktime.content.identifier"]).toBe("ABC-123"); // pairing kept
  });
});

describe("tribute video", () => {
  it("reads every tribute value from the canonical design tokens", () => {
    setTokenOverrides(null);
    const tk = tributeTokens();
    for (const v of Object.values(tk)) expect(v).not.toBeNull();
  });

  it("renders with the canonical tokens (real shapes, no overrides)", async () => {
    setTokenOverrides(null);
    const tk = tributeTokens();
    const cards = [{ image: await testJpeg(3, { width: 900, height: 1200 }), name: "Ana", line: "happy birthday & thank you for everything <3" }];
    const v = await renderTribute(cards, { title: "Happy birthday, Lea!", end: "We love you!" }, tk, path.join(WORKER_ROOT, "fonts"));
    const f = tmpFile("real.mp4");
    fs.writeFileSync(f, v.mp4);
    const p = await probe(f);
    const vs = p.streams.find((s) => s.codec_type === "video")!;
    expect(vs.codec_name).toBe("h264");
    expect(Math.abs(Number(p.format.duration) * 1000 - v.durationMs)).toBeLessThan(100);
  }, 180_000);

  it("fails with a clear missing-design-token error when a value is absent", () => {
    setTokenOverrides({ "duration.birthday.tribute.photoHold": null });
    expect(() => tributeTokens()).toThrow(MissingTokenError);
    expect(() => tributeTokens()).toThrow(/missing design token duration\.birthday\.tribute\.photoHold/);
  });

  it("renders title card → contribution cards (hard cuts) → end card with the token timings", async () => {
    setTokenOverrides(TEST_TRIBUTE_TOKENS);
    const tk = tributeTokens();
    const cards = [
      { image: await testJpeg(1, { width: 800, height: 600 }), name: "Ana", line: "happy birthday & thank you for everything <3" },
      { image: await testJpeg(2), name: "Rui", line: "the best summer was with you" },
    ];
    const v = await renderTribute(cards, { title: "Happy birthday, Lea!", end: "from Lima family" }, tk, path.join(WORKER_ROOT, "fonts"));
    // 1000 title + 500 fade + 2×1000 photos + 1000 end
    expect(v.durationMs).toBe(4500);
    const f = tmpFile("t.mp4");
    fs.writeFileSync(f, v.mp4);
    const p = await probe(f);
    const vs = p.streams.find((s) => s.codec_type === "video")!;
    expect([vs.codec_name, vs.width, vs.height]).toEqual(["h264", 360, 640]);
    expect(Math.abs(Number(p.format.duration) - 4.5)).toBeLessThan(0.1);
    expect((await sharp(v.poster).metadata()).width).toBe(360);
    // the first frame of a contribution card shows the photo pillarboxed on the token color
    const frame = tmpFile("f.png");
    execFileSync("ffmpeg", ["-loglevel", "error", "-y", "-ss", "2.0", "-i", f, "-frames:v", "1", frame]);
    const px = await sharp(frame).extract({ left: 2, top: 2, width: 1, height: 1 }).raw().toBuffer();
    expect(Math.max(px[0]!, px[1]!, px[2]!)).toBeLessThan(24);
  });
});
