# `account.delete.web` — account deletion web page (`GET /delete-account`)

Google Play requires every app that lets people create an account to give "a web link resource where users can request
that their account and associated data is deleted" without reinstalling the app, which must "prominently reference the
app or developer name", "prominently feature the steps users should take" and "specify the types of data that are deleted
or kept, and any additional retention period" (https://support.google.com/googleplay/android-developer/answer/13327111,
read 2026-10-17). Apple asks the same of apps with accounts inside the app (App Review Guideline 5.1.1(v)); the in-app
path is `settings.account` → Delete Account.

Visual reference: the invite page's state card / column (`invite.web` "States": same card on mobile, same column on
desktop; headline in the headline's place, the 62 % lines under it, the pill for the one action) — no new value. Copy:
the in-app rows' own names and `account.delete.web.*` (design/copy/account.json).

## References

| id | file / URL | used for |
|---|---|---|
| GP | https://support.google.com/googleplay/android-developer/answer/13327111 | what the page must contain |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `delete_account_page_title` ("Delete Account"), `settings_title_contact_us` ("Contact Us") | headline, action |
| WEBX | `references/auto/retro/web/retro.app-web-copy-excerpts.txt` /downloads ("Need help or a new link? Contact the person who sent you this package.") | the request line's shape |
| HIG | Apple and Google support pages write paths as "Settings > General" | the in-app path's " > " |

## Structure

The `invite.web` state page (mobile card on `color.global.backgroundDeep`, desktop column on white), top to bottom:

1. Headline `settings.account.delete` ("Delete Account").
2. Line `account.delete.web.inApp` with `{path}` = `groups.list.tab.me.accessibilityLabel` > `settings.root.title` >
   `settings.root.account` > `settings.account.delete` (the rows a person taps: Profile > Settings > Edit Profile >
   Delete Account, the same on iOS and Android).
3. Line `settings.account.delete.footer` + `account.delete.web.kept` (what goes; nothing is kept).
4. Line `settings.account.delete.subscriptionNote` (store subscriptions are cancelled in the store).
5. Only with `config/app.json` `support.email`: line `account.delete.web.request` with the address as a `mailto:` link,
   then the pill (mobile) / link (desktop) `settings.root.contact` → `mailto:`.
6. Footer as every web page: Terms & Privacy, and `&nbsp;·&nbsp;` `settings.root.contact` when `support.email` is set.

## States

| state | design |
|---|---|
| default (support address set) | as Structure |
| no support address yet | items 1–4 and the footer; no request line or action (check_setup warns: Google Play needs the address) |
| loading / empty / error / offline / permission-denied | not applicable (static page, no data) |

## Accessibility

One `<h1>`; lines are `<p>`; the action is a link with its visible text; contrast as `invite.web` state pages.

## Data & actions

None: a static page. Deletion itself is `delete_account()` in the app (docs/API.md), or by the owner on an emailed
request (docs/OWNER_SETUP.md §8.3). Linked from Play Console → App content → Data safety → "Delete account URL" and from
docs/PRIVACY_LABELS.md.
