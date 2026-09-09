#!/bin/bash
# Adds somebody to the Dev System roster AFTER their Supabase account exists.
# Creating the account itself is a dashboard job: Authentication > Users > Add user.
# Usage: ./add-dev-user.sh kishini@bb-leads.app KISHINI "Head of Development" admin
E="$1"; N="$2"; T="$3"; R="${4:-dev}"
[ -z "$E" ] && { echo "usage: $0 <email> <DISPLAY NAME> <title> [admin|dev]"; exit 1; }
cat <<SQL
insert into dev_users (user_id, display_name, title, role)
select id, '$N', '$T', '$R' from auth.users where email = '$E'
on conflict (user_id) do update set display_name=excluded.display_name,
  title=excluded.title, role=excluded.role, active=true;
select display_name, title, role from dev_users
  where user_id = (select id from auth.users where email='$E');
SQL
