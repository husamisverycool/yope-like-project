// What keeps the service from starting in production: BLOCKED copy and missing configuration.

import { blockedConfig, type Config } from "./config.js";
import { missingCopy } from "./design.js";

export function startupProblems(config: Config, copySource?: Readonly<Record<string, string>>): string[] {
  return [
    ...missingCopy(copySource).map((k) => `copy ${k} (BLOCKED or missing; see design/BLOCKED.md)`),
    ...blockedConfig(config),
  ];
}
