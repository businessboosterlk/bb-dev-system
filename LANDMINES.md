# BB Dev OS — LANDMINES

Registered landmines for `~/bb-dev-system/index.html`. Read before changing anything.
Created 2026-07-30 from the first full audit of this system.

---

## L-DEV-001 — This system is NOT on the shared anon posture. Do not "fix" it to match.

**Status: live design, protect it.**

Every other BB system authenticates name+PIN locally and reads with the anon key, so every
table it touches needs an anon or public SELECT. That rule is written into the BB shared
ground truth, and applying it here would be a serious security regression.

This system is different. `initSupabase()` (index.html:843) calls
`sb.auth.signInWithPassword(APP_AUTH)` and reads as a real **authenticated** Postgres role.
Verified 2026-07-30 against project `yyviiwnqgphyklcoijyd`: all ten `dev_*` tables carry
exactly one policy, `authenticated_all [authenticated]`, with **no anon and no public grant**.

If someone applies the Command Centre anon-parity pattern (`FOR ALL TO public USING(true)`)
to the `dev_*` tables because the shared rule says to, they publish the entire developer
work board, keyring and deploy log to the open internet. The anon-parity rule does not apply
to this system. Check `initSupabase` before assuming any BB system's posture.

---

## L-DEV-002 — CLOSED 2026-09-01. The shared credential is gone from the file.

**Status: FIXED. The file is now safe to publish.**

`APP_AUTH` and the four name+PIN logins have been deleted. Each person signs in with their
own Supabase account, typed at the login screen and never stored, and their name and level
come from the new `dev_users` table (self-read only, so the roster is not a directory).
`initSupabase()` no longer authenticates anything; it only builds the client.

**The migration trap, and the guard for it.** Browsers that used the old build still held the
shared `nirvana` session in local storage, and `getSession()` returned it — so removing the
constant alone would have walked those users straight in as the shared account. Boot now
accepts a stored session ONLY if its user has a `dev_users` row, and calls `signOut()`
otherwise. Verified: a browser carrying the old session lands on the login screen with zero
rows loaded. Removing a credential is not finished until the sessions it minted are dead.

Verified: `guard.py` PASSES for the first time (L-015 and L-006 both clear), no password
string remains anywhere in the file, wrong password refused, account with no `dev_users` row
refused, nothing fetched before sign-in, harness 63/63 twice at 390px and 1280px.

Seeded in `dev_users`: THULAIB and SHIARA, from their existing `bb-leads.app` accounts.
**KISHINI and HIRAN have no Supabase account yet** and cannot sign in until Thulaib creates
them in the dashboard and their `dev_users` rows are added.

The ORIGINAL finding, kept for the record:

index.html:525
```
const APP_AUTH={email:'nirvana@bb-leads.app',password:'pin2222secure'};
```

This is a real, live account (`auth.users`, last sign-in 2026-07-30). The name+PIN login
above it (Thulaib/Shiara/Hiran) is **cosmetic**: it gates which name renders in the sidebar,
not which database session opens. Everyone who loads the page gets the same authenticated
session regardless of the PIN they type, and the PINs themselves are in the same file.

What that one session actually reaches, verified read-only:
- `clients` — `authenticated_all`, all commands, and the table carries `package`, `mrr`,
  `health`.
- `pipeline` — authenticated select/insert/update/**delete** on the whole sales pipeline.
- `crm_profiles`, `crm_tenants` — authenticated read.
- all ten `dev_*` tables — full access.

It is not exposed to the public today only because the repo is private and Pages is not
serving (see L-DEV-004). The credential becomes public the moment Pages is switched on.
**Fix the credential first, then publish.** This is the role-floor Mold 6 problem
(`bb-role-floor`), and applying it is gated on Thulaib's per-system go.

---

## L-DEV-003 — "The dev must not see client money" is a client-side convention, not a rule.

**Status: OPEN, same fix as L-DEV-002.**

index.html:859 reads:
```
/* deliberate: never select mrr/package/health - the dev role must not see client money */
q('clients','id,name,industry,client_type',x=>x.order('name')),
```

The intent is right and the column list is correct. But the restriction lives only in that
one select string. The database grants the session full access to `clients`, so anyone with
the file can open devtools and run `sb.from('clients').select('*')` to get every client's
MRR, package and health. Same class as the Command Centre "finance flat" finding in the
role-floor dry-run.

A comment is not an access control. Money is hidden by RLS or it is not hidden.

---

## L-DEV-004 — The README promises a live URL that returns 404.

**Status: OPEN, needs Thulaib.**

README says `Live: https://businessboosterlk.github.io/bb-dev-system`. Verified 2026-07-30:

| check | result |
|---|---|
| `.../bb-dev-system/` and `/index.html` | HTTP **404**, body `Site not found · GitHub Pages` |
| `businessboosterlk.github.io/bb-os-academy/` (control) | HTTP **200** |
| `api.github.com/repos/businessboosterlk/bb-dev-system` anonymously | HTTP **404** → repo is private |
| `git ls-remote` over SSH | works, remote `main` = local `main` = `556d7b0` |

The control proves the org's Pages and the network are fine. "Site not found" is the
repo-level Pages 404, not a missing-file 404. A private repo on GitHub Free cannot publish
Pages, which alone explains it.

Timeline worth knowing: last commit 28 Jul 08:09 IST, Hiran's last login 28 Jul 16:45 IST,
and the machine migration with its documented silent restore failures was 29 Jul. Every
file in the repo is dated 29 Jul 11:05, i.e. restored. Whether Pages was ever enabled and
was lost in that migration is **not proven** — `gh` is not installed on this machine and the
GitHub API will not answer anonymously for a private repo. Confirm in the GitHub UI.

Do not resolve this by making the repo public. See L-DEV-002.

---

## L-DEV-005 — A network blip turns the self-test red.

**Status: OPEN, small fix, not yet applied.**

index.html:509
```
window.addEventListener('unhandledrejection',e=>rec('rejection',[e.reason&&e.reason.message||String(e.reason)]));
```

`guard.py` flags this as L-006: the handler has no network-noise filter. Two harness checks
read `__ST_LOG` for `kind==='rejection'` — "No uncaught errors at boot" (index.html:2153) and
"Harness added no stray errors" (index.html:2297). A failed Supabase fetch on flaky wifi
pushes a rejection entry and fails both, for a reason that is not a code defect.

This is the only system with a self-test harness, so it is the one place a false red costs
the most: a harness that cries wolf gets waved through, and the next real failure goes with
it. Filter `failed to fetch` / `networkerror` / `network request failed` before recording.

---

## L-DEV-006 — CLOSED 2026-08-03. The app used to fake a working system when the database was down.

**Status: FIXED.**

Old boot path (index.html:2342): if `initSupabase()` failed, the app printed a 5-second toast and
**silently switched to demo**, rendering `seedData()` — invented clients, invented SSL warnings —
as though it were live work. Anyone glancing at the screen a minute later was reading fiction.
Same class as the "0/12" fallback that lied: a fallback must change how a number is LABELLED,
never quietly substitute one.

Now: `showConnectionFailure()` blocks the login screen, disables both fields and the button,
says "Cannot reach the database. Nothing has been loaded.", and offers Try again plus an explicit
Open sample data link. Boot **returns before `fetchAll()`** so nothing loads and nobody gets in.
Demo mode itself is untouched and still backs the self-test harness.

Sibling fix, same commit: `fetchAll()`'s per-table error handler used to swallow failures and
return `[]`, so a 401 on `dev_items` rendered an empty board reading "no work". Failed tables are
now collected in `LOAD_FAILED` and named on screen by `renderLoadWarn()`.

Verified: forced `initSupabase` to return false and re-ran the real `boot()` — `fellBackToDemo:false`,
`fetchWasCalled:false`, `letUserIn:false`, fields disabled. Harness 50/50 twice at 390px and 1280px.

---

## L-DEV-008 — THE NO MONEY RULE. Never put a price back in this tool.

**Status: enforced by the harness.**

Thulaib confirmed 2026-08-03 that developers are **salaried, not commissioned**, so the whole
commission feature had no reader. Removed: the Reports Commission tab and `repCommissionHtml()`,
the Project value and Commission fields on the job popup, the Project value / Commission % inputs
on the job form and the save that wrote them, plus `fmtLKR()` and the seeded money values.

The removed ledger had shown a `Value` column, i.e. **what the client paid for the site**, which
contradicted the README's own house rule of "no client money rendered anywhere". Rule and build
now agree.

The permanent block is a harness check, not a comment: **"NO MONEY RULE: no price or commission
renders on any page"** sweeps every page for `/LKR\s*[\d,]/` and `/commission/i` and names the
offending page. Proven both ways — it caught a stale "commission math" line in the System page
blurb that a read-through had missed, and a deliberately reintroduced `LKR 350,000` on Deploys.

**The database columns were NOT touched.** `dev_items.project_value`, `commission_pct` and
`commission_paid` still exist and still hold their values. Nothing reads or writes them from the
app. Dropping them is a schema change and needs a separate sign-off; do not assume the numbers
are gone just because the screens are clean.

---

## L-DEV-009 — "Master" currently gates nothing.

**Status: OPEN, decision needed.**

`canAdmin()` (index.html:927) was used in exactly one place: the commission ledger. With that gone,
the only remaining caller is the self-test harness. So KISHINI (`role:'admin'`) and HIRAN
(`role:'dev'`) now have **identical** powers in the app.

The role field, `canAdmin()` and the harness check are all deliberately kept as the hook for
whatever should be gated next — likely candidates are deleting work items, editing the Keyring, or
seeing other people's jobs. Until something is wired to it, do not describe the master login as a
permission boundary, because it is not one.

---

## L-DEV-007 — Client money is readable by the anon key across the whole fleet.

**Status: OPEN, bigger than this system, needs Thulaib.**

Verified 2026-08-03 on `clients`: role `anon` holds **SELECT, INSERT, UPDATE and DELETE**, and the
`public access` policy is `FOR ALL` to PUBLIC. The table carries `package`, `mrr`, `health`.

The anon key ships in the source of every BB system, and three of them are already publicly served.
So every client's MRR is already readable by anyone who views source on those sites, and client rows
are deletable the same way. This is why L-DEV-003 cannot be fixed from inside the Dev System: even a
perfect role floor here changes nothing while `clients` is wide open fleet-wide.

Do **not** simply revoke it. `clients` must stay anon-readable or the Command Centre 401s — that is
L-CC-001, already paid for once. The fix is a narrowed view for the anon surface plus money columns
restricted to authenticated finance roles, and it has to be planned across the Command Centre, SMM,
Video and Graphic systems together, not here.

---

## Verified GOOD — do not "fix" these

- **The Keyring holds no keys, and means it.** `looksLikeSecret()` (index.html:667) guards
  both the notes and holder fields, is enforced again on save (index.html:1597), and is
  covered by a harness check. The page footer states it. This page is not the credential
  risk; L-DEV-002 is.
- **No base64 image landmine.** Images upload to the `task-images` Storage bucket
  (index.html:1303, bucket exists and is public) and only the short public URL is stored.
  The comments list query selects `image_url`, which is correct here because it is a URL,
  not a data URI. Do not apply the Graphic System base64 fix to this system.
- **`clients` carries both `authenticated_all` and `public access`** — the L-CC-001 fix from
  2026-07-21 is still in place.

---

## Audit evidence, 2026-07-30

- JS parses: single inline block, 192,107 chars, PARSE OK via JavaScriptCore
  (`node` is not installed on this machine). Checker proven by injecting a deliberate
  syntax break and watching it fail.
- `guard.py`: 1 FAIL, L-006 only (L-DEV-005 above).
- Self-test harness: **50/50 ALL GREEN**, twice at 390px and twice at 1280px.
  `documentElement.scrollWidth` equals the viewport at both widths. Zero console errors.
  Run in demo mode, live data untouched.
- Anti-AI-tells sweep: 0 eyebrow dashes, 0 gradient text, 0 pulsing dots, 0 blur orbs,
  0 emoji. `text-size-adjust` present, `svg` sizing rule present.
- L-CC-002 escape class: 0 literal `\uXXXX` in the HTML or CSS zones.

## Usage reality, 2026-07-30

The system is built but not fed. Row counts: `dev_items` 1, `dev_stage_history` 1,
`dev_weekly_plan` 1, and **0** in `dev_client_access`, `dev_properties`, `dev_recurring`,
`dev_deploys`, `dev_item_comments`, `dev_seo_ranks`. `team_login_logs` shows 6 dev-system
logins ever, all by HIRAN, last on 28 Jul — against 113 for video-system, 91 for
smm-workspace, 83 for graphic-system.

Consequences: the Care engine has no templates so it spawns nothing, the Keyring's
"wall of red to clear" is empty, and Deploys is empty. The signature features cannot be
judged working or broken from live data because they have never been given any.

---

## L-DEV-010 — Daily checks and monthly content went live 2026-09-01.

Four tables added on Thulaib's go: `dev_seo_clients`, `dev_daily_checks`, `dev_blog_posts`,
`dev_month_report`. All four are `authenticated_all` with **no anon and no public policy**,
matching L-DEV-001. Do not "fix" them to the shared anon pattern.

**A tick is a TIME and a NAME, never a bare boolean.** Shape taken from `smm_publish_log`,
BB's best existing tick. Each table carries a `*_who_and_when` CHECK constraint enforcing the
pair. Proven live: inserting a check with `checked_at` set and `checked_by` null is refused
with 23514, and a duplicate blog slot is refused by the unique key.

Live setup: 3 properties under daily care (Home Depot website, Waverley website, BSWL system),
4 clients on 4 blog posts a month, 4 pending website builds on the board.

**Still open, both need Thulaib.** (1) RUGBY CODE has no `clients` row, so its build is filed
with `client_id NULL` and reads as "BB Internal" on screen. (2) `clients` id 51 is spelled
**"Business Bosster"** with industry 'Automotive' and package 'Ignite'; it was used for Business
Booster's blogs and website build on a name match alone. Both are one-line fixes to `clients`,
a table this system does not own, so neither was done here.

## L-DEV-PAGES-01 (2026-09-18): the Pages deploy can hang, and re-running does not always unstick it
The icon commit `227bf6c` landed on main and the GitHub Pages deploy failed with
`Error: Failed to get ID Token ... Request timeout`, a fault on GitHub's side and not in the change.
`gh run rerun` then sat QUEUED for over half an hour while githubstatus.com reported every component
operational. What actually shipped it was cancelling the stuck run and pushing a fresh commit to
main, because a new push queues a new build rather than reviving a dead one.

**How to apply.** If the live site is stale and the newest run is `queued` for more than about ten
minutes, do not wait and do not edit the workflow or the Pages settings. Cancel the run and push
something real to main. Check what is actually being served, never what the run page claims:

    curl -s -o /dev/null -w "%{size_download}\n" "https://businessboosterlk.github.io/bb-dev-system/icon-512.png?cb=1"

About 115,000 bytes is the current estate icon. About 40,988 bytes is the old cropped wordmark.

---

## L-DEV-012 — 2026-09-21. L-DEV-001 REVERSED. This system now matches the estate.

**L-DEV-001 was wrong and it cost Thulaib two weeks.** It recorded the authenticated
posture as deliberate design. It was not. It was an accident of how this system happened
to be built, and on 1 September it was hardened further, which left the CEO unable to add
a single person without opening the Supabase dashboard. The Video, Graphic and SMM systems
never had that problem: all three use name plus PIN and read with the public key.

The Video System is the proof. Its login is `YOUR NAME` and a `PIN`, and the file carries
this comment right beside it: *"NO SHARED LOGIN. A signInWithPassword used to run here,
before anyone..."*. Video hit the same shared-credential problem and fixed it the same way.
**It removed the shared credential and KEPT the simple login.** On 1 September this system
threw away both. Only one of them was the hole.

**The PIN was never what protected the database, in any of the six systems.** It decides
whose name renders and what they can see. What protects the data is the row policy.

Applied on Thulaib's go: all fourteen `dev_*` tables moved to `dev_public` FOR ALL TO
public with anon grants, the same posture as the rest of the estate. `crm_*` untouched,
Leads untouched. Verified with the public key: `dev_items` 200 with rows, `crm_profiles`
**401**.

**What this opens, said plainly.** Anyone with the public URL can read the work board, the
client list and the deploy notes. Not passwords, the Keyring holds none by design. Not
client money, it is not in this tool. The Command Centre already runs this way and it holds
client revenue, so this is no more open than what BB already operates.

---

## L-DEV-013 — A name in a lookup is a bug with a start date.

`devMemberId()` read `DATA.team.find(m => m.name.toUpperCase() === 'HIRAN')`. The day Hiran
left and his row went `active = false`, that returned nobody, so every job the Care engine
spawned would have had **no owner** and nobody would have been told. It never threw.

Now found by ROLE: `/develop/i.test(m.role)`, first active match. Finds VIRAJ today and
whoever follows him, with no code change. Same lesson as `shared-tables-need-a-department`:
filter by MEANING, never by a name list.

Hiran's two jobs and four weekly plan rows were reassigned to Viraj before his login was
removed. His `team_members` row stays `active = false`, never deleted, so every stage move
he made still says who did it. His seeded demo records keep his name for the same reason.

---

## L-DEV-014 — 2026-09-21. Three checks a day, an owner on every plan row, a derived day list.

**The plan had no owner field and fell back to a name.** `savePlan` set
`assigned_to = CURRENT ? CURRENT.name : 'HIRAN'` on create and never touched it on edit. So
nobody could hand a job to anybody, and the fallback named a person who had left. The form
now carries "Who is doing it", read from `USERS` so it can only ever offer people who can
actually sign in, and it saves on edit as well as create.

**Two nav items shared one icon.** The shared `@@BB_SETTINGS_*@@` block builds its button by
CLONING the last nav item, so it inherited System's gear. System is the health and self-test
page, so it took a pulse line and the gear stayed with Settings, where it belongs. When two
buttons look identical, check whether one is a clone before redrawing either.

**Three checks a day, held in one table.** `SLOTS` at the top of the file is the only place
the day's checks are listed. The table header, the cells, the due count and the modal title
all read it. Thulaib set three on 21 Sep; a fourth is one line here plus one value in the
database constraint.

**The day list is DERIVED, never typed.** `myChecklist()` computes every line from live data
and returns a longer list for the head than for the junior: the junior sees the checks, their
own work and their own plan; the head also sees blocked work, blog posts, client reports,
certificates inside thirty days and any planned job with nobody's name on it. A checklist
somebody types by hand is stale the week after it is written.

## L-DEV-015 — a call to a function that lives on another branch
**Found 2026-09-22, live, by signing in as KISHINI on a local copy of main.**

`doLogin()` on `main` ended with `if(MODE!=='demo')maybeRunHarness();`. `maybeRunHarness`
is part of the bug catcher, which was built on `bugfix/2026-09-09` and **never merged**.
So every real sign-in on the live site threw `ReferenceError: maybeRunHarness is not
defined`. Nobody reported it because `signIn(u)` runs on the line before, so the screen
still opened and the error was silent.

Fixed by guarding the call: `typeof maybeRunHarness==='function'`. The branch is still
unmerged and the bug catcher is still not running on the live system.

**The lesson.** A cherry-picked line from a branch is a call into a function that does not
exist. When a branch is abandoned, grep main for every name the branch introduced.
This is the second thing that has gone missing from `bugfix/2026-09-09` (the crossorigin
fix was the first). MERGE IT OR DELETE IT.

## L-DEV-016 — a shared board that never said whose work it was
**Thulaib, 2026-09-22: "make sure Kishini can add the weekly plan for him as well and she
can see everybody's stuff".**

Nothing was hiding anyone's work. The Weekly Plan had always rendered every row in the
week for every signed-in person, and the owner field shipped on 2026-09-21. But the card
printed the title, the work type and the client and **never the name**, so a board of nine
rows looked identical whoever was looking at it, and there was no way to ask "what is
Viraj doing this week".

Fixed with the smallest two things that answer it: an owner chip on every card (amber
`Nobody` when unassigned, which feeds the head's "every planned job has a name on it"
row) and a Whose week filter carrying a count per person.

**The lesson.** "Can she see everybody's stuff" is usually not a permissions question.
Check what the screen PRINTS before you go looking at who can read what.

## L-DEV-017 — signing in never loaded anything
**Found 2026-09-22, on the LIVE site, while re-verifying L-DEV-016.**

Signed in as KISHINI on `businessboosterlk.github.io/bb-dev-system/` and the whole app
read zero: 0 open work, "Morning check on 0 sites", "nothing under care yet", an empty
Weekly Plan. A direct `sb.from('dev_weekly_plan').select('*')` in the same tab returned
**25 rows**, and `LOAD_FAILED` was empty. Nothing was broken in the database or the
policies. **Nothing had been fetched.**

Two holes, both on the paths a human actually uses:

1. `doLogin()` called `signIn(u)`, and `signIn` ends with `go('today')`. Neither of them
   fetches. So a person who typed their name and PIN saw a fully rendered, completely
   empty system until the three-minute refresh timer fired.
2. The restored-session path in `boot()` did `await fetchAll(); renderLoadWarn();` and
   then **never repainted**, because `signIn` had already drawn Today against empty data.

Fixed: `doLogin` is async, loads first with the button reading "Loading your work" and
only then opens the app (1.2 to 1.5 seconds measured); the restore path now calls
`updateBell(); renderPageRefresh()` after its load. Three harness checks read the SOURCE
of `doLogin` and `boot`, because the harness runs in demo mode and can never exercise
the live path.

**The lesson, and it is the same one as L-DEV-006.** A screen full of zeros and a screen
full of "still loading" look identical, and the zeros are the more convincing lie because
they are laid out neatly. The harness had 72 green checks and every one of them ran
against seeded demo data, so not one of them ever watched the sign-in path load anything.
**Test the door people walk through, not the room behind it.**

## L-DEV-018 — the alert button had nothing behind it
**Thulaib, 2026-09-22: "DOES THE APP ALERTS WORK ON THIS".**

No. Counted live: 0 alert rules for any `dev_*` table against 17 for the rest of
the estate, 0 triggers, 0 alerts ever queued from this system, 0 rows in
`agent_alerts` for `system = 'dev'`, and 0 phones subscribed from this app out of
38 across the estate. The push block, the bell and the "Alerts off, tap to turn
on" pill had all shipped on 5 September. Nothing on the other side had.

Also found: `team_members.is_head` was **false** for Kishini while her role read
"Dev Head". Every alert rule in the estate finds a head by that flag and never by
the job title, so any rule naming the head of development would have resolved to
nobody, silently. Same shape as the fault that hid every alert from the video
head for weeks.

Also found: the Dev System had **no hash router at all**. `go()` never wrote a
hash and nothing read one, so a phone alert carrying `#daily` would have dropped
the person on Today. The estate's own contract says every alert carries `#route`
to the screen that answers it.

Fixed: four alerts in a `bb_dev_*` namespace, the head flag set, a hash router,
and `updated_by` stamped in one place by the write seam so no alert can ring the
person who caused it. Map at `~/bb-dev-system/ALERTS.md`.

**The lesson.** A switch on a wall is not a light. This app had shown every user
a control that said "Alerts off, tap to turn on" for seventeen days, and turning
it on would have changed nothing. **When a feature has a visible control and an
invisible half, count the invisible half before you call the feature present.**

## L-DEV-019 — a development team looking at 28 marketing clients
**Thulaib, 2026-09-22: "WHY HAVE WE ADDED EVERY SINGLE CLIENT".**

Nothing added them. The Dev System reads the shared `clients` table, the same one
the Command Centre and every other BB system reads, and `renderClients` printed
all of it with no filter. Development holds something for **6** of those 28.

Fixed with a filter, not a deletion, because a new website gig starts with a
client this page has never seen: **We work on 6 / Every BB client 28**, opening on
the six. A client counts as ours when development holds a site under care, active
blog posts, open board work, a login or a job on the plan.

**The lesson.** Reading a shared table is not the same as owning its rows. When a
system reads an estate-wide table, the DEFAULT view has to be the slice that
system is responsible for, and the rest stays one tap away. Nobody notices this
while the table is small.

## L-DEV-020 — WAVERLEY rendered as "WAVER LEY"
Found in the same screenshot. `.hrow b` carried `word-break:break-word`, and on a
390px screen the badges squeezed the name column to 44px, so every client name
snapped mid-word across three lines. Fixed by letting the badges drop to their own
line below the name under 560px, and by banning a break inside a word outright.
Measured after: every name one line, 17px tall, no horizontal scroll.

**Two process notes from finding it.** The first fix did nothing because the media
query sat ABOVE `.hrow .grow` and lost the cascade on equal specificity. The
second appeared to do nothing because the cache buster had been written as
`#clients?r=2`, which puts it in the FRAGMENT: the document URL never changed and
the browser served the cached page. **A query string after a hash is not a query
string.** Read the computed style rather than the screenshot when a CSS change
looks ignored: `getComputedStyle` said `flex-wrap: nowrap` while the file said
`wrap`, and that one line named both faults.

## L-DEV-021: quiet hours hold the evening check alert to the next morning (FIXED 7 Oct 2026, decision 108)
**Found 6 Oct 2026 in the evening audit (DEV-1). Nothing changed.**

`bb-dev-checks-evening` runs `31 12 * * 1-5`, 18:01 Colombo, one minute after the evening
window closes at 18:00 (ALERTS.md row 1: 11:01, 15:01 and 18:01). The quiet hours shipped
that morning move anything queued at or after 18:00 to 07:00 the next working day, so
"Evening check missed" now reaches Kishini and Viraj at 07:00 and Friday's lands on Monday.
The window closes after 17:55, so the job was NOT moved: there is no gap between the close
and 18:00 to put it in. `bb_dev_checks_missed` has no clock of its own; the close time lives
only in ALERTS.md. Rechecked 7 Oct: jobid 42 still `31 12 * * 1-5`, `bb_notify_send_after`
still holds anything at or after 18:00. ALERTS.md still says quiet hours start at 21:00.

Two ways out, both Thulaib's. One: close the evening window at 17:30 and run the job at
12:01 UTC. Two: drop the evening alert. Either starts from `cron.job` jobid 42.

**The lesson.** Moving a shared clock (quiet hours) moves every alert scheduled near it.
Before changing one, run `bb_notify_send_after` over every bb-* cron schedule.

**Fixed 7 Oct 2026.** Thulaib chose way one ("17:30"). Jobid 42 now runs `1 12 * * 1-5`, 17:31
Colombo, and `bb_notify_send_after` returns the same minute for it on a weekday, Friday included.
The function and the other two jobs are unchanged. Detail and proof in ALERTS.md, "Decision 108".

## L-DEV-022: two alert functions anyone with the public key could run
**Found 6 Oct 2026 (DEV-2), closed the same evening.**

`bb_dev_checks_missed` and `bb_dev_blogs_short` are SECURITY DEFINER and carried EXECUTE for
PUBLIC (`=X/postgres`), so anon and authenticated could call them through the REST API. Their
only dedupe is one row per date and slot, so a call with `p_dry false` and an old `p_date`
queued a real alert for any weekday in history. Checked first: no call to either name in the
nine `index.html` apps under `~/bb-*/` or in the 18 deployed edge functions; only the four
pg_cron jobs call them, as postgres. Revoked from PUBLIC, anon and authenticated.
`has_function_privilege` after: anon false, authenticated false, postgres true, service_role
true on both. Rollback: `~/bb-systems/push/rollback/dev-fn-execute-2026-10-06-BEFORE.sql`.

**The lesson.** Postgres grants EXECUTE to PUBLIC by default. A function only a scheduler
should run gets its REVOKE in the same migration that creates it.

## L-DEV-023: the card owner picker still found its default by name
**Second instance of L-DEV-013 (DEV-4), 6 Oct 2026.**

`openItemForm` pre-selected the member named HIRAN. He left on 21 Sep, nothing matched and
there was no blank option, so the browser took the first active member of staff in heap
order: SUHANA, a graphic designer. `bb_dev_notify_on_item` then alerted her about a website
fault while the developer heard nothing. The list also held every member of staff.

Now the list is Nobody plus dev roles only (`isDevRole`, the same `%dev%` test the alert
functions use). A new card starts on `devMemberId()`. An edited card keeps its current owner
in the list even outside a dev role, so saving an edit never moves the job. Probe: a new card
lists Nobody, KISHINI, VIRAJ and selects VIRAJ; an edited card on SUHANA keeps SUHANA.

**The lesson.** L-DEV-013 was fixed where it was found (the Care engine) and left in the
picker beside it. When a name lookup turns up, grep the file for every `=== '<NAME>'` before
calling it fixed.

## L-DEV-024: none of the nine phone foundations were in the file
**Found 6 Oct 2026 (DEV-5).**

0 uses each of touch-action, tap-highlight, touch-callout, user-select, enterkeyhint, inert,
scrollRestoration, dvh and pointer:coarse. Fields were 14px, so tapping any field zoomed an
iPhone and stayed zoomed; Back left the app instead of closing a sheet. The BBF block was cast
from bb-graphic-system: CSS at the end of the stylesheet, script at the end of the body. Three
adaptations, each marked ADAPTED in the code:

- Overlays `.modal-ov, .nav-mask, .cmdk-ov, .st-ov, #bbset-back`; keep list `#bbset-sheet`
  only. `#sidebar` sits inside `#app` beside its own mask, so listing it (as Graphic does)
  would stop `#app` ever being shielded behind a modal.
- Modals here close by being REMOVED (`closeModal` empties `#modalRoot`) and the palette
  arrives inside a wrapper. The graphic observer reacts only to an added overlay node, so a
  closed modal left the page pinned until the two second watchdog freed it. The observer now
  also reacts to an overlay inside an added wrapper or a removed one.
- `go()` rewrites the current history entry with replaceState, so a jump made from the
  palette replaced the overlay's own entry and the close's `history.back()` would have undone
  the jump. The close now steps back only over an entry that is still ours.

Measured at 390 and 1440: field 16px on the phone and 14px on the desk; an open modal pins
the body and shields `#app`; Back once closes it and stays in the app; Cancel unpins in about
65ms; a palette jump to Board sticks; Settings is recognised and sits at 88dvh. In-app
self-test 84 of 84 at both widths before and after. Finished 7 Oct: the skill's checks went
into the self-test (A8) and a hand-over fault was found and fixed, see L-DEV-031.

**The lesson.** A block proven on one app carries that app's markup in its selectors and its
observer. Read how THIS app opens and closes its overlays before casting, then prove the close
path by measuring.

## L-DEV-025: the service worker reached across every BB app on the origin
**Found 6 Oct 2026 (DEV-6).**

All six apps share one origin and a cache belongs to the origin, not the app. `activate`
deleted every cache not named `bb-dev-system-v1`; `notificationclick` focused the first window
of ANY BB app. Measured with the old worker: `bb-video-system-v3` and `bb-smm-workspace-v2`
were deleted the moment the Dev worker activated. With the new one both survive and the old
`bb-dev-system-v0` still goes. An alert tap now reuses only a window inside the worker's scope.

**The lesson.** On a shared origin every cache list and every window list is shared. Filter by
your own prefix and your own scope.

## L-DEV-026: supabase-js loaded from a floating major with no integrity
**Found 6 Oct 2026 (DEV-7).**

`@supabase/supabase-js@2` meant any new 2.x release reached the live app with no change in this
repo. Pinned to 2.117.2 (what `@2` served that day) as the static file `dist/umd/supabase.js`
with a sha384 `integrity` and `crossorigin="anonymous"`. The floating URL cannot carry SRI:
jsDelivr prepends a generated header to it. The floating body without that header is byte for
byte the pinned file. Three fetches gave the same hash. Boot check after: the library
loads, 0 page errors.

To upgrade: change the version, recompute with
`curl -sL <url> | openssl dgst -sha384 -binary | openssl base64 -A`, re-run the boot check.

## L-DEV-027: the write seam reported to a function that did not exist
**Second instance of L-DEV-015 (DEV-8), 6 Oct 2026.**

DBW sent every failed insert, update and delete to `window.bbReportDbError`, which exists only
on the unmerged bugfix branch, so a refused write reached one toast and nobody else. A small
reporter now sits beside DBW: the console always, then at most one `system_bug_log` row per
table every ten minutes (app `dev-system`, category `db_write`), the row shape the SMM
Workspace uses. Checked first: anon holds INSERT on `system_bug_log` (policy public_all).
Silent in demo and on localhost.

**The lesson.** A guarded call (`window.X&&window.X()`) hides a missing function for good. When
a guard goes in to stop a crash, the missing thing goes on the list the same day.

## L-DEV-028: the no secrets guard covered the Keyring only
**Found 6 Oct 2026 (DEV-9).**

`looksLikeSecret` ran on the Keyring's notes and holder. Name, Hosted where, How to deploy,
Known gotchas and Supabase project went to `dev_properties` unchecked, comments went to
`dev_item_comments` unchecked. Both tables are readable with the public key. Both saves
now refuse with the Keyring's own words. URL and Repo stay out on purpose: the guard flags any
run of 24 path characters, so `github.com/org/name` (the seeded demo repos) would be refused as
a credential. Live rows checked first: 0 existing values would be refused.

**The lesson.** A guard on one form protects that form. Put it where the data is written. When
the guard is a heuristic, run it over the real values before switching it on.

## L-DEV-029: comments still said Dev signs in with Supabase
**Found 6 Oct 2026 (DEV-10).**

Three comments (the config block, the USERS header and the data layer header) described
per person Supabase accounts and "silent app auth", none of it true since L-DEV-012. That is
why the 6 Oct brief called Dev the one app on real Supabase Auth. Comments corrected only.
`dev_users` (3 rows, read by nothing in the file) is left for Thulaib's yes.

**The lesson.** When a decision reverses, grep the file for every sentence that described the
old one.

## L-DEV-030: the bell reads a table no Dev alert is written to (OPEN)
**Found 6 Oct 2026 (DEV-3). Not fixed: the right table is closed to this app.**

`fetchAll` loads `agent_alerts` where system is dev or all, which holds 0 Dev rows. Every Dev
alert goes to `bb_notify_queue` (34 rows since 23 Sep). The bell could not be pointed there:
`has_table_privilege('anon','bb_notify_queue','SELECT')` is false, RLS is on with no policy
and this app reads as anon. It needs a decision first: a narrow security definer read of one
member's dev_* rows or a view. Until then the bell says No alerts every day. Rechecked
7 Oct: anon SELECT still false, RLS on, 0 policies on `bb_notify_queue`.

## L-DEV-031: a modal opened from the search palette was dead to every tap
**Found 7 Oct 2026 finishing DEV-5, before it shipped.**

The BBF layer built its shield once, when the first overlay opened. Opening a card, client
or site from the search palette removes the palette and fills `#modalRoot` in the same tick,
so the next sync saw an overlay still open on a page still pinned and did nothing. The
shield was the palette's: `#modalRoot` stayed inert and the new modal took no tap and no
key. Probe at 390 and 1440: `elementFromPoint` on the modal returned the body, inert list
`statusfill, loginScreen, app, modalRoot, toast`. Fixed by re-shielding whenever the open
overlay is not the one the shield was built for; the pin and the history entry carry over.
After: the point hits the modal and `#modalRoot` is not inert; Back still closes it.

The 6 Oct cast also shipped without the skill's checks, which is how this got past it. The
self-test now carries them (A8, 13 checks, 84 to 97) including this hand-over. Proven to
bite: with the re-shield line removed the self-test fails exactly that check at both widths.
Its first version passed with the line removed, because it opened the palette while a modal
already held the shield; it now opens the palette on a freed page, as a person does. While
the checks drive the layer, `history.pushState` and `history.back` are stood in for and put
back, so a run never queues a Back that would land after the report.

**The lesson.** An overlay layer that reacts only to open and closed misses a swap. Test the
hand-over between two overlays. Run a new check once against the fault before trusting it.

## L-DEV-032: three faults the reviewer found in the 6 Oct audit fixes (FIXED 7 Oct 2026)
**The secrets guard refused ordinary runbook text.** Once looksLikeSecret ran on the runbook and on comments, a
server path such as /home/businessboosterlk/public_html/dev and a full commit hash read as credentials, so a
property whose runbook held a path could not be saved. Paths that start a word, host/path addresses and
40 character commit hashes are now taken out before the 24 character test. Tested on seven cases: a path, a
repo address and a commit hash pass; a live key, a token, an access key pair and "password:" are still refused.
**A page jump under an open overlay kept the old scroll.** The phone foundation freeze put the left page's
offset back on the new page. go() now tells the freeze the new page starts at the top.
**Back closed the wrong overlay.** anyOpen returned the first open overlay in the document, not the top one, so
with the menu under Settings, Back closed the menu. It returns the top one now. A backdrop is never shielded
by another overlay.
**Lesson: a guard that refuses honest text is a guard people learn to get round. Test it on what the team
really types before it ships.**

## L-DEV-033 · the PINs left the page; the server checks them · 2026-10-07 (bb_pending 97, Thulaib: "do this")
Closes the PIN half of L-DEV-012. The four name and PIN pairs are gone from index.html. They live bcrypt-scrambled in
`app_pin` (RLS on, no policy, no grant: the public key gets "permission denied"), seeded from the old values hashed on the
Mac so nobody was locked out. Sign-in calls `app_pin_login` (five wrong tries lock the name 15 minutes) and keeps a 12 hour
pass; a refresh restores only through `app_session_check`, so a name typed into sessionStorage lands on the login screen.
Sign-out calls `app_session_end`. Demo asks for no PIN. Proven on a throwaway ZZTEST seat (deleted after): wrong PIN
refused, right PIN in, forged pass refused, valid pass restores, sign-out kills the pass server-side; self-test 97 of 97.
TRAP HIT: a supabase-js call with no await or .then is never sent, so the first sign-out cleared the tab and left the
pass alive. Block: every fire-and-forget sb call ends in .then(function(){},function(){}).
STILL OPEN: the old four PINs are in git history and earlier deploys, so Thulaib must set new ones
(`select public.app_pin_set('dev','NAME','new pin');` in the SQL editor). The dev_* tables stay open to the public key;
only the role floor closes the data. Mould: ~/bb-systems/app-pin/.

