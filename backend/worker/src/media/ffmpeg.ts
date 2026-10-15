// ffmpeg / ffprobe as child processes, with a timeout and the CPU time ffmpeg reports itself
// (-benchmark prints "bench: utime=…s stime=…s rtime=…s").

import { spawn } from "node:child_process";

export interface RunResult {
  stdout: string;
  stderr: string;
  /** user + system CPU seconds as reported by ffmpeg -benchmark (0 when not reported) */
  cpuSeconds: number;
  wallMs: number;
}

export class FfmpegError extends Error {
  override name = "FfmpegError";
}

export function run(bin: string, args: string[], opts: { timeoutMs?: number; cwd?: string } = {}): Promise<RunResult> {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const child = spawn(bin, args, { cwd: opts.cwd, stdio: ["ignore", "pipe", "pipe"] });
    const out: Buffer[] = [];
    const err: Buffer[] = [];
    child.stdout.on("data", (c: Buffer) => out.push(c));
    child.stderr.on("data", (c: Buffer) => err.push(c));
    const timer = setTimeout(() => child.kill("SIGKILL"), opts.timeoutMs ?? 10 * 60_000);
    child.on("error", (e) => {
      clearTimeout(timer);
      reject(new FfmpegError(`${bin}: ${e.message}`));
    });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      const stderr = Buffer.concat(err).toString("utf8");
      if (code !== 0) {
        reject(new FfmpegError(`${bin} exited with ${code ?? signal}: ${stderr.split("\n").slice(-6).join(" | ")}`));
        return;
      }
      const bench = /bench: utime=([\d.]+)s stime=([\d.]+)s/.exec(stderr);
      resolve({
        stdout: Buffer.concat(out).toString("utf8"),
        stderr,
        cpuSeconds: bench ? Number(bench[1]) + Number(bench[2]) : 0,
        wallMs: Date.now() - started,
      });
    });
  });
}

export function ffmpeg(args: string[], opts?: { timeoutMs?: number; cwd?: string }): Promise<RunResult> {
  return run("ffmpeg", ["-hide_banner", "-nostdin", "-loglevel", "error", "-benchmark", ...args], opts);
}

export interface ProbeStream {
  index: number;
  codec_type: string;
  codec_name?: string;
  width?: number;
  height?: number;
  tags?: Record<string, string>;
}

export interface ProbeResult {
  format: { duration?: string; format_name?: string; tags?: Record<string, string> };
  streams: ProbeStream[];
}

export async function probe(file: string): Promise<ProbeResult> {
  const r = await run("ffprobe", ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", file], { timeoutMs: 60_000 });
  return JSON.parse(r.stdout) as ProbeResult;
}

/** QuickTime / MP4 metadata keys that carry a location. */
export function locationTags(p: ProbeResult): string[] {
  const keys = new Set<string>();
  const scan = (tags?: Record<string, string>) => {
    for (const k of Object.keys(tags ?? {})) if (/location|gps|iso6709/i.test(k)) keys.add(k);
  };
  scan(p.format.tags);
  for (const s of p.streams) scan(s.tags);
  return [...keys];
}
