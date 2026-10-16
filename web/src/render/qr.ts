// Surface: invite.web — desktop QR code of the invite link (design/surfaces/invite.web.md "Structure — desktop";
// reference: references/auto/retro/web/retro.app-u-nathan-desktop.png, Retro's QR with the inviter's photo in its
// centre). Encoder: qrcode-generator (MIT). Error correction level H (≈30 % of codewords recoverable) because the
// avatar (invite.web.size.avatarDesktop) covers the code's centre, as on Retro's page.
//
// Inline SVG: square modules drawn in currentColor (the stylesheet sets it), one path; the page around it is the
// quiet zone. Decorative for assistive technology: the line next to it ("Scan the code …") says what it is.

import qrcode from "qrcode-generator";

export function qrSvg(data: string, className: string): string {
  const qr = qrcode(0, "H");
  qr.addData(data, "Byte");
  qr.make();
  const n = qr.getModuleCount();
  let d = "";
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; ) {
      if (!qr.isDark(r, c)) {
        c++;
        continue;
      }
      let run = 1;
      while (c + run < n && qr.isDark(r, c + run)) run++;
      d += `M${c} ${r}h${run}v1h-${run}z`;
      c += run;
    }
  }
  return `<svg class="${className}" viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges" aria-hidden="true" focusable="false"><path fill="currentColor" d="${d}"/></svg>`;
}
