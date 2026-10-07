# BB DEV OS: THE ALERT MAP

Built 22 September 2026. Before this date the Dev System had a working alert
button and nothing behind it: 0 rules, 0 triggers, 0 alerts ever queued, while
the other four systems shared 17 rules and 652 queued alerts.

## The rule this stack lives under

The estate push stack (`bb_notify_on_stage`, `bb_notify_on_plan`, `bb_notify`,
`bb_push_health`, the `bb-push` edge function) is SINGLE OWNER and the Dev
System is not that owner. See `~/bb-systems/push/README.md` and L-PUSH-004.

So nothing here edits a shared function. Everything the Dev System owns is in
its own `bb_dev_*` namespace and touches only `dev_*` tables. The one shared
thing it does is INSERT into `bb_notify_queue`, which is exactly what every
other system does.

`bb_notify_on_stage` could not have been reused even if the ownership rule
allowed it: it reads `new.current_stage`, `assigned_editor_id` and
`assigned_designer_id`, and resolves a head only for graphic and video roles.
`dev_items` has none of those columns.

## The four alerts

| # | Fires when | Goes to | Link |
|---|---|---|---|
| 1 | A check window closes with a site unticked, 11:01, 15:01 and 17:31 Colombo, Monday to Friday (the evening window closes at 17:30, decision 108, 7 Oct 2026) | Head of development and every active developer | `#daily` |
| 2 | Somebody puts a job on your week, or hands one to you | The person it lands on | `#plan` |
| 3 | A card is logged or turns critical, live or blocking | Head of development plus whoever it is on | `#board` |
| 4 | The 20th at 09:00 Colombo with blog posts short | Head of development and the CEO | `#monthly` |

## What is deliberately silent

- **Ticking your own job done.** The one habit that teaches a team to ignore
  the channel is a phone that rings for something you just did yourself.
- **Your own additions to your own week.** `created_by` or `updated_by` equal
  to the assignee returns early.
- **A card that was already hot.** Only the crossing into critical, live or
  blocking is news, never every later edit of it.
- **Saturday and Sunday** for the three daily checks. The BB week is Monday to
  Friday.
- **Quiet hours 18:00 to 07:00 Colombo and the whole weekend**, applied
  estate-wide by `bb_notify_send_after` (18:00 since 6 Oct 2026), so nothing
  here can ring at night. Anything queued in those hours waits for 07:00 on the
  next working day.

## What it is made of

Functions `bb_dev_notify_on_plan()`, `bb_dev_notify_on_item()`,
`bb_dev_checks_missed(slot, dry, date)`, `bb_dev_blogs_short(dry, date)`.
Triggers `bb_dev_plan_alert` on `dev_weekly_plan`, `bb_dev_item_alert` on
`dev_items`. Cron `bb-dev-checks-morning` `31 5 * * 1-5`,
`bb-dev-checks-midday` `31 9 * * 1-5`, `bb-dev-checks-evening` `1 12 * * 1-5`,
`bb-dev-blogs-20th` `30 3 20 * *`, all UTC. Unique index
`bb_notify_queue_dev_once_per_day` so a repeat run cannot send twice.
Columns `dev_weekly_plan.updated_by` and `dev_items.updated_by`, stamped in one
place by `ACTOR_TABLES` in the app's write seam.

## Rehearse without sending

    select * from bb_dev_checks_missed('am', true);
    select * from bb_dev_blogs_short(true);

The dry run performs the REAL insert and rolls it back, because a dry run that
skips the insert proves nothing (L-PUSH-001).

## Proven 22 September 2026

Inside a rolled-back transaction:

- Kishini plans a job for Viraj → **VIRAJ**
- Viraj plans his own job → **nobody**
- Viraj logs a live fault on Waverley → **KISHINI**
- Kishini ticks her own row done → **nobody**

Then end to end through the real app in a browser: Kishini signed in, added a
job for Viraj, and the queue held one alert to VIRAJ carrying
`.../bb-dev-system/#plan`. Both rows deleted afterwards, this week's nine plan
rows untouched.

Dry runs on live data: all three daily slots read 3 sites under care, 0 ticked,
and rehearsed an insert to 2 recipients. The blog check read 16 due, 0 posted,
and rehearsed an insert to 3.

## Decision 108, 7 Oct 2026: the evening window closes at 17:30

Thulaib's answer was "17:30". Until then the evening job ran at 18:01 Colombo
(`31 12 * * 1-5`), one minute after a window that closed at 18:00. The quiet
hours begin at 18:00, so "Evening check missed" waited for 07:00 the next
working day and Friday's landed on Monday (L-DEV-021).

What changed: cron jobid 42 `bb-dev-checks-evening` moved to `1 12 * * 1-5`,
17:31 Colombo. Nothing else. `bb_dev_checks_missed` has no clock of its own, so
the function is unchanged. The morning (jobid 40) and midday (jobid 41) jobs
are untouched. The app shows no window times (the Daily Checks columns read
Morning, Midday and Evening), so no label changed.

Proof, read live 7 Oct 2026:

- `bb_notify_send_after` at 17:31 Wednesday returns 17:31 the same day (sent at
  once). At 18:01 it returned 07:00 Thursday (held). At 17:31 on Friday 9 Oct it
  returns 17:31 Friday.
- `select * from bb_dev_checks_missed('pm', true);` read 3 sites under care with 0
  ticked. It rehearsed a real insert to 2 recipients and rolled it back.

Undo: `~/bb-systems/push/rollback/bb-dev-checks-evening-2026-10-07-BEFORE.sql`.
Migration: `~/bb-systems/push/migrations/bb_dev_checks_evening_1731_2026_10_07.sql`.

## THE OPEN ONE

**Kishini and Viraj have zero phones registered.** 38 devices exist across the
estate and not one of them is subscribed from the Dev System. Until each of
them opens the app, goes to Settings and taps the alert pill, every alert above
queues correctly and reaches nobody. On an iPhone it only works from the app
added to the Home Screen, never from Safari.

Check it with:

    select m.name, count(s.id) as devices
    from team_members m left join bb_push_subscriptions s on s.team_member_id = m.id
    where m.active and lower(m.role) like '%dev%' group by m.name;
