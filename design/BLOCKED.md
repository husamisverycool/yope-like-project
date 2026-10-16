# BLOCKED values

Generated. These may not ship; release builds fail to compile if code uses any of them.

| item | surface | why |
|---|---|---|
| token `question.weekly.layout.rotation` | question.weekly | Lead decision. Split out of the draft's question.weekly.layout.schedule ('rotation: BLOCKED') so the schedule can ship. Server: app_config weekly_question_keys is NULL until decided, so no question is asked (docs/API.md §14.4). |
| token `question.weekly.layout.defaultOn` | question.weekly | Lead decision; the references disagree and neither is a group setting. Server today: groups.weekly_question default off, turned on by an admin (docs/API.md §14.4). |
| token `camera.overnight.layout.stackCards` | camera.overnight | Lapse's stack is measurable only as a whole (bounding box including its glow), so its cards and fan inside size.global.circleButtonLarge cannot be traced; until a capture closes it the leading slot stays empty in 9 AM mode (the library circle is hidden). Smallest capture: one raw screenshot of Lapse's stack and a 60 fps recording of its shutter press up to the stack update. |
| copy `year.story.card.app` | year.story | App line under the group name on the recap card and the full-bleed footer (Retro prints its domain). BLOCKED until the owner names the app (and its domain); until then the line is left out. |
| copy `plans.page.went` | plans.page | Past-plan list label. BLOCKED: Partiful's word appears only with a count ('{n} Went'); the word alone is not evidenced as a label. Smallest capture: a screenshot of a past Apple Invites event's guest list. |
| copy `widget.countdown.empty.noPlans` | widget.countdown | BLOCKED: no reference widget shows an empty plan state (Apple Invites' empty widget not captured; design/research/plans.md §12 item 7); pattern-only text. Smallest capture: one screenshot of the Apple Invites widget with no upcoming event. |
