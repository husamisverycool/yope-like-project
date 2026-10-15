// Glyphs drawn on the web page. They are the Android values of the icon tokens (Material Icons,
// Apache License 2.0, https://github.com/google/material-design-icons), inlined as SVG paths:
//   invite.web.icon.lock     → Material Icons "lock"        src/action/lock/materialicons/24px.svg
//   invite.web.icon.getApp   → Material Icons "north_east"  src/navigation/north_east/materialicons/24px.svg
// Size and colour come from the tokens at the call site; the paths are glyph data, not design values.

import { tokens } from "../design.js";

const PATHS: Record<string, string> = {
  "Filled.Lock":
    "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z",
  "Filled.NorthEast": "M9,5v2h6.59L4,18.59L5.41,20L17,8.41V15h2V5H9z",
};

/** Decorative inline SVG for an icon token (hidden from assistive technology). */
export function icon(name: "invite.web.icon.lock" | "invite.web.icon.getApp", className: string): string {
  const android = (tokens[name] as { android: string }).android;
  const d = PATHS[android];
  if (!d) throw new Error(`no web glyph for ${name} (${android})`);
  return `<svg class="${className}" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path fill="currentColor" d="${d}"/></svg>`;
}
