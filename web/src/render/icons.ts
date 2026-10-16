// Glyphs drawn on the web page. They are the Android values of the icon tokens (Material Icons,
// Apache License 2.0, https://github.com/google/material-design-icons), inlined as SVG paths:
//   icon.global.person → Rounded.Person   src/social/person/materialiconsround/24px.svg
// Size and colour come from the tokens at the call site; the paths are glyph data, not design values.

import { tokens } from "../design.js";

const PATHS: Record<string, string> = {
  "Rounded.Person":
    "M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v1c0 .55.45 1 1 1h14c.55 0 1-.45 1-1v-1c0-2.66-5.33-4-8-4z",
};

/** Decorative inline SVG for an icon token (hidden from assistive technology). */
export function icon(name: "icon.global.person", className: string): string {
  const android = (tokens[name] as { android: string }).android;
  const d = PATHS[android];
  if (!d) throw new Error(`no web glyph for ${name} (${android})`);
  return `<svg class="${className}" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path fill="currentColor" d="${d}"/></svg>`;
}
