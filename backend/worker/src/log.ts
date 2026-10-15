// Structured logs: one JSON object per line on stdout ({ts, level, msg, ...fields}).

export type LogLevel = "debug" | "info" | "warn" | "error";
const ORDER: Record<LogLevel, number> = { debug: 10, info: 20, warn: 30, error: 40 };

export type LogFields = Record<string, unknown>;
export type LogSink = (line: LogFields) => void;

export interface Logger {
  debug(msg: string, fields?: LogFields): void;
  info(msg: string, fields?: LogFields): void;
  warn(msg: string, fields?: LogFields): void;
  error(msg: string, fields?: LogFields): void;
  child(fields: LogFields): Logger;
}

function serialize(value: unknown): unknown {
  if (value instanceof Error) {
    return { name: value.name, message: value.message, stack: value.stack?.split("\n").slice(0, 6).join("\n") };
  }
  return value;
}

export const stdoutSink: LogSink = (line) => {
  process.stdout.write(JSON.stringify(line, (_k, v) => serialize(v)) + "\n");
};

export function createLogger(opts: { level?: LogLevel; sink?: LogSink; base?: LogFields } = {}): Logger {
  const min = ORDER[opts.level ?? "info"];
  const sink = opts.sink ?? stdoutSink;
  const base = opts.base ?? {};
  const emit = (level: LogLevel, msg: string, fields?: LogFields) => {
    if (ORDER[level] < min) return;
    const line: LogFields = { ts: new Date().toISOString(), level, msg, ...base };
    if (fields) for (const [k, v] of Object.entries(fields)) line[k] = serialize(v);
    sink(line);
  };
  return {
    debug: (m, f) => emit("debug", m, f),
    info: (m, f) => emit("info", m, f),
    warn: (m, f) => emit("warn", m, f),
    error: (m, f) => emit("error", m, f),
    child: (fields) => createLogger({ level: opts.level, sink, base: { ...base, ...fields } }),
  };
}

/** Collects log lines in memory (tests). */
export function memoryLogger(level: LogLevel = "debug"): { log: Logger; lines: LogFields[] } {
  const lines: LogFields[] = [];
  return { log: createLogger({ level, sink: (l) => lines.push(l) }), lines };
}
