# `support.web` — support page (`GET /support`)

App Store Connect requires a Support URL on every version, and it "must lead to actual contact information (legal
address, email address, telephone number), as may be required by local law, so that users can reach you regarding app
issues, general feedback, and feature enhancement requests"
(https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information, read
2026-10-17). The only site the app has is the invite page's service, so it serves the owner's support address
(`config/app.json` `support.email`) at `/support`.

Visual reference: the `account.delete.web` page (the invite page's state card on mobile, column on desktop) — no new
value. Copy: `settings.root.contact` (the app's own "Contact Us" row, Retro's `settings_title_contact_us`); the address is
the owner's data.

## Structure

1. Headline `settings.root.contact` ("Contact Us").
2. Line: the address, as a `mailto:` link.
3. Footer as every web page: Terms & Privacy · Contact Us.

## States

| state | design |
|---|---|
| default (support address set) | as Structure |
| no support address yet | not served: the `not_found` state page, 404 (check_setup warns while `support.email` is empty) |
| loading / empty / error / offline / permission-denied | not applicable (static page, no data) |

## Accessibility

One `<h1>`; the address is a link whose visible text is the address; contrast as `invite.web` state pages.

## Data & actions

None: a static page. Entered in App Store Connect → the version → **Support URL** (docs/OWNER_SETUP.md §12).
