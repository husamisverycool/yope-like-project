// Surface: invite.web — desktop QR code of the invite link (design/surfaces/invite.web.md "Structure — desktop";
// reference: references/auto/retro/web/retro.app-u-nathan-desktop.png, Retro's QR with the inviter's photo in its
// centre). Encoder: qrcode-generator (MIT). Error correction level H (≈30 % of codewords recoverable) because the
// avatar (invite.web.size.avatarDesktop) covers the code's centre, as on Retro's page.
//
// Inline SVG of `size` CSS px: square modules of a whole number of CSS px (crisp at every device pixel ratio), centred,
// drawn in currentColor (the stylesheet sets it) as one path; the page around them is the quiet zone. Retro's code is
// drawn the same way (references/auto/retro/web/retro.app-u-nathan-desktop.png: 231-px ink in the 250-px box = 33
// modules × 7 px). Decorative for assistive technology: the line next to it ("Scan the code …") says what it is.

import qrcode from "qrcode-generator";

export function qrSvg(data: string, className: string, size: number): string {
  const qr = qrcode(0, "H");
  qr.addData(data, "Byte");
  qr.make();
  const n = qr.getModuleCount();
  const k = Math.max(1, Math.floor(size / n));
  const o = Math.floor((size - n * k) / 2);
  let d = "";
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; ) {
      if (!qr.isDark(r, c)) {
        c++;
        continue;
      }
      let run = 1;
      while (c + run < n && qr.isDark(r, c + run)) run++;
      d += `M${o + c * k} ${o + r * k}h${run * k}v${k}h-${run * k}z`;
      c += run;
    }
  }
  return `<svg class="${className}" viewBox="0 0 ${size} ${size}" shape-rendering="crispEdges" aria-hidden="true" focusable="false"><path fill="currentColor" d="${d}"/></svg>`;
}
