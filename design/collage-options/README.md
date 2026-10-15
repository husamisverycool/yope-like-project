# Same-moment collage — options for the owner

No app combines a whole group's simultaneous answers into one image, so the directive (Part 3)
allows only two sources: **BeReal's dual image** (how one answer looks) and **Yope's collage
composition** (how answers sit together). Every option below uses the same answer tile from BeReal
and a different Yope composition. Please pick **A**, **B** or **C**.

Sample sheets (rendered by the production compositor, `backend/worker/src/collage/`, with CC0 /
public-domain test photos; every 9th answer has no front photo, to show the single-camera case):
`option-A.jpg`, `option-B.jpg`, `option-C.jpg` — each shows 1, 2, 3, 5, 8, 12, 20 and 30 people.
Re-render with `cd backend/worker && npm run collage:options`.

## The answer tile (all options) — BeReal

| decision | value | evidence | level |
|---|---|---|---|
| back photo shape | 3:4 portrait | BeReal post preview 786×1048 exactly (bereal.md §3, H2) | SOURCED |
| front photo position | inset at the top-left | H3, H2, App Store preview #205 | SOURCED |
| inset width | 0.31 × tile width | 5 sources agree 0.308–0.313 (bereal.md §3) | SOURCED |
| inset margin | 0.030 × tile width, same on top and left | H3 35.2 px both axes; HG 24 px both axes | SOURCED |
| inset border | 0.0051 × tile width (2 pt at 393 pt), #000000 | H3 6 px at 3x, exact (0,0,0) | SOURCED |
| inset corners | outer 0.126 × inset width; inner = outer − border | H3 / HG circle fits | SOURCED |
| answer without a front photo | back photo alone | BeReal shows the inset only when there is a second photo | SOURCED |
| order | capture time, then member id | not a design value (stable, deterministic) | — |

## Option A — "recap card" (Yope week recap, `references/owner/yope-week-recap.jpg`)

Tiles touch (0 gap), equal columns, square inner corners and rounded outer corners. A row with
fewer answers goes first and spans the full width. The image grows taller with more people.

| decision | value | evidence | level |
|---|---|---|---|
| columns | 3 | recap grid rows 2–3 (yope-b.md §6, C1) | CAPTURED |
| gap | 0 | seams at x 207.5 / 332.5, no gutter | CAPTURED |
| outer corners | 0.0359 × width (12 pt on a 334 pt card) | bottom-corner profile, ±3 pt | CAPTURED |
| inner corners | square | C1 | CAPTURED |
| short row first, spanning the width | yes | C1 row 1 holds 2 tiles across the full width | CAPTURED |

Not observed in Yope (would need one more reference): how a short row splits its width (we split
equally; C1 shows an unequal 61/39 split for its one example) and that row's height (C1's top row
is cut off; we use the normal row height, so 1–2 people become a wide strip).

## Option B — "wall pages" (Yope walls: 9:16 canvas, paged)

Each page is 9:16, the shape of Yope walls and their exports. 3 columns × 4 rows of 3:4 tiles fill
a 9:16 page exactly (3 × 4/9 = 16/9), so tiles touch with no cropping. More than 12 people continue
on further pages (swiped like Yope's recap card). A page is directly an Instagram-Stories-shaped
share image.

| decision | value | evidence | level |
|---|---|---|---|
| page shape | 9:16 | wall editor 804×1430 px; profile wall tiles 185×329 pt; export preview (yope-b.md §8 C4, C5, C7) | SOURCED |
| columns | 3 | Yope's 3-column grids (C1, C2, C3) | SOURCED |
| rows per page | 4 | follows from 3 columns of 3:4 tiles on 9:16 | derived |
| gap | 0 | wall photos abut (C5, C6) | SOURCED |
| page corners | 0.0498 × width (20 pt on 402 pt) | wall canvas corners (C5) | SOURCED |
| paging | horizontal pages | recap card page dots (C1) | CAPTURED |
| empty cells on a part-filled page | black (#000000) | the matte color; empty cells themselves are not observed in Yope | SOURCED color, layout not observed |

Not observed: what Yope does with a part-filled page. With few people most of the page is black.

## Option C — "pics grid" (Yope profile pics grid, press kit Jul 2026)

Small gaps between tiles, rounded tiles, black background, side insets. The image grows taller
with more people.

| decision | value | evidence | level |
|---|---|---|---|
| columns | 3 | profile "pics" grid (yope-b.md §5, C3) | SOURCED |
| gap | 0.0102 × width (4 pt on 393 pt) | C3 | SOURCED |
| side insets | 0.0611 × width (24 pt) | C3 | SOURCED |
| tile corners | 0.0565 × tile width (6.5 pt on 115 pt) | C3 | SOURCED |
| background | #000000 | C3 profile background; BeReal background (both #000000) | SOURCED |
| tile shape | 3:4 | BeReal; C3's own tiles are 0.73, within 0.02 | SOURCED |

Not observed: top and bottom margins (we reuse the side inset) and how a short last row aligns
(we left-align).

## What the choice changes elsewhere

- **Widgets** show the collage filling the widget (Locket's photo fill), cropped to the widget's
  shape. A and C crop the top of a tall image; B's first page is already portrait.
- **Share to Stories** needs 9:16 (Meta's doc: 9:16 or 9:18, ≥ 720×1280). B's pages are 9:16 as is;
  for A and C the share image places the collage on a 9:16 canvas, a layout no reference shows. If
  you pick A or C, the share layout needs one more decision or reference.
- **History, walls, recaps** show the image as rendered.

## To close the "not observed" gaps (optional)

One screen recording of a Yope weekly recap card for a week with only 2–5 photos (to see how Yope
fills a short row or a part-empty card). With it, A or B can be finished without any unsourced rule.
