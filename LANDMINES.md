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
