-- BB Dev OS — Drafts: temporary draft / preview / demo links, one place.
-- Written and applied 2026-11-20 on Thulaib's go.
--
-- Additive only: one new table. Nothing existing touched. Rollback at the bottom.
--
-- POSTURE: authenticated only, like every dev_* table (LANDMINES L-DEV-001).
-- Do NOT add an anon or public policy: this table holds TEST passwords.
--
-- PASSWORD EXCEPTION (L-DEV-020): the Keyring rule "never store credentials"
-- still stands for REAL client access. This table is the one deliberate
-- exception, approved by Thulaib 2026-11-20, for throwaway TEST logins on
-- draft builds only. Real client logins (Instagram, hosting, domain, GSC)
-- never go here.

begin;

create table if not exists dev_drafts (
  id             bigint generated always as identity primary key,
  client_id      bigint references clients(id) on delete set null,
  name           text not null,
  url            text not null,
  host           text,            -- vercel, github pages, railway, netlify, other
  status         text not null default 'draft'
                 check (status in ('draft','review','approved','live','archived')),
  test_username  text,
  test_password  text,            -- TEST credentials only, see header
  notes          text,
  created_by     text,
  updated_by     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table dev_drafts enable row level security;
revoke all on dev_drafts from anon;
create policy authenticated_all on dev_drafts for all to authenticated using (true) with check (true);
grant select, insert, update, delete on dev_drafts to authenticated;

commit;

-- ROLLBACK
-- drop table if exists dev_drafts;
