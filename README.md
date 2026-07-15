# BB Dev OS

The BB internal system that tracks the developer's work across four types: System, Website, Maintenance, SEO.

- Live: https://businessboosterlk.github.io/bb-dev-system
- Demo mode (sample data, nothing saves): add `?demo=1`
- Self-test: add `?selftest` or System page > Run self-test. Gate: ALL GREEN at ~390px AND desktop, twice each.

## Runbook
- Single file: `index.html` (inline CSS + JS, no build).
- Deploy: push to `main`, GitHub Pages rebuilds in ~2 min, hard refresh.
- Backend: shared BB Supabase (`yyviiwnqgphyklcoijyd`), tables `dev_*` only, plus reads of `clients` (never money columns), `team_members`, `agent_alerts`, writes to `team_login_logs`.
- Validate JS before push: extract the script block, `node --check`.
- Gotcha: `client_id` is bigint; every select value is coerced with `Number()`.

## House rules written into the tool
Root-Cause Lock on bugs, receipt line on client work, no deploy log without a rollback pointer, the Keyring never stores credentials, blocked is a flag not a stage, no client money rendered anywhere.
