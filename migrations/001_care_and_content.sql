-- BB Dev OS — daily checks, blog posts and the monthly client report
-- Written 2026-09-01. NOT APPLIED. Needs Thulaib's go before anything runs.
--
-- Additive only: four new tables, no change to any existing table, no data touched.
-- Rollback is at the bottom and drops only what this file creates.
--
-- POSTURE NOTE, read before changing anything here.
-- The Dev System reads as `authenticated`, NOT anon (see LANDMINES.md L-DEV-001).
-- Every dev_* table uses `authenticated_all`. These four match that. Do NOT add an
-- anon or public policy to them, even though the shared BB rule says to for other
-- systems, or you publish the developer's work log to the open internet.

begin;

-- 1. WHICH CLIENTS GET BLOG POSTS, and how many a month.
--    Kept as a table rather than a hardcoded 4 so the number can change per client
--    without a code change.
create table if not exists dev_seo_clients (
  id              bigint generated always as identity primary key,
  client_id       bigint not null references clients(id) on delete cascade,
  posts_per_month integer not null default 4 check (posts_per_month between 1 and 30),
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  unique (client_id)
);

-- 2. THE TWICE-DAILY CHECK.
--    A tick is a TIME and a NAME, never a bare boolean — the shape proven in
--    smm_publish_log. The CHECK constraint enforces the pair, so a tick can never
--    exist without saying who made it.
create table if not exists dev_daily_checks (
  id           bigint generated always as identity primary key,
  check_date   date not null,
  slot         text not null check (slot in ('am','pm')),
  property_id  bigint not null references dev_properties(id) on delete cascade,
  checked_at   timestamptz,
  checked_by   text,
  bugs_found   boolean not null default false,
  note         text,
  created_at   timestamptz not null default now(),
  unique (check_date, slot, property_id),
  constraint dev_daily_checks_who_and_when
    check ((checked_at is null) = (checked_by is null))
);
create index if not exists dev_daily_checks_date_idx on dev_daily_checks (check_date desc);

-- 3. THE FOUR BLOG POSTS PER CLIENT PER MONTH.
--    slot is 1..4 (or higher if posts_per_month is raised). Same who-and-when pair.
create table if not exists dev_blog_posts (
  id            bigint generated always as identity primary key,
  client_id     bigint not null references clients(id) on delete cascade,
  target_year   integer not null check (target_year between 2020 and 2100),
  target_month  integer not null check (target_month between 1 and 12),
  slot          integer not null check (slot between 1 and 30),
  title         text,
  url           text,
  posted_at     timestamptz,
  posted_by     text,
  created_at    timestamptz not null default now(),
  unique (client_id, target_year, target_month, slot),
  constraint dev_blog_posts_who_and_when
    check ((posted_at is null) = (posted_by is null))
);

-- 4. THE MONTHLY CLIENT REPORT TICK. One row per client per month.
create table if not exists dev_month_report (
  id            bigint generated always as identity primary key,
  client_id     bigint not null references clients(id) on delete cascade,
  target_year   integer not null check (target_year between 2020 and 2100),
  target_month  integer not null check (target_month between 1 and 12),
  done_at       timestamptz,
  done_by       text,
  note          text,
  created_at    timestamptz not null default now(),
  unique (client_id, target_year, target_month),
  constraint dev_month_report_who_and_when
    check ((done_at is null) = (done_by is null))
);

-- RLS: identical to every other dev_* table. authenticated only, no anon, no public.
alter table dev_seo_clients   enable row level security;
alter table dev_daily_checks  enable row level security;
alter table dev_blog_posts    enable row level security;
alter table dev_month_report  enable row level security;

create policy authenticated_all on dev_seo_clients  for all to authenticated using (true) with check (true);
create policy authenticated_all on dev_daily_checks for all to authenticated using (true) with check (true);
create policy authenticated_all on dev_blog_posts   for all to authenticated using (true) with check (true);
create policy authenticated_all on dev_month_report for all to authenticated using (true) with check (true);

grant select, insert, update, delete on dev_seo_clients, dev_daily_checks, dev_blog_posts, dev_month_report to authenticated;

commit;


-- ============================================================================
-- THE REAL SETUP, from Thulaib's list of 2026-09-01.
-- Run this AFTER the tables exist. Ids confirmed against the live clients table.
--   HOMEDEPOT 3 · CEYLON CARRIER TRAVELS 12 · BS WITH LEON 14 · SAPPHIRE TRAILS 50 · WAVERLEY 52
-- ============================================================================

-- Under daily care: two websites and one system.
insert into dev_properties (client_id, name, type, url) values
  (3,  'Home Depot website', 'website', null),
  (52, 'Waverley website',   'website', null),
  (14, 'BSWL system',        'system',  null);

-- On four blog posts a month.
-- BUSINESS BOOSTER IS DELIBERATELY OMITTED — see the two open questions below.
insert into dev_seo_clients (client_id, posts_per_month) values
  (3, 4), (52, 4), (50, 4);


-- ============================================================================
-- TWO THINGS I COULD NOT RESOLVE. Both need Thulaib before the setup is complete.
--
-- 1. RUGBY CODE has no row in `clients` at all, so its website-development work
--    cannot be recorded against a client. Creating a client row is a write to a
--    table this system does not own, so it is not in this file.
--
-- 2. "BUSINESS BOOSTER" is ambiguous. clients id 51 is spelled "Business Bosster"
--    and carries industry 'Automotive' and package 'Ignite', which does not read
--    like BB itself. It is either a typo'd internal row or a real client that was
--    misnamed. BB's own blog posts and web work are therefore NOT set up above.
--    Confirm which it is and I will add it.
--
-- Also unconfirmed: whether the monthly client report is due for all four blog
-- clients or only the two on SEO plus maintenance. The screens currently show a
-- report tick for every client on blogs, which is the wider reading.
-- ============================================================================


-- ============================================================================
-- ROLLBACK. Drops only what this file creates. Existing tables untouched.
-- ============================================================================
-- begin;
-- drop table if exists dev_month_report;
-- drop table if exists dev_blog_posts;
-- drop table if exists dev_daily_checks;
-- drop table if exists dev_seo_clients;
-- delete from dev_properties where name in ('Home Depot website','Waverley website','BSWL system');
-- commit;
