#!/bin/bash
# Lago's API, Sidekiq worker and clock side by side. Upstream runs them as
# separate containers sharing /app/storage (invoice PDFs, exports); Railway
# can't mount one volume into two services, so they share a container instead.
# Without the worker and clock no invoice, webhook or PDF is ever produced.
# If any of the three exits, the container exits and Railway restarts it.
set -euo pipefail
cd /app

# Railway mounts the volume root-owned, with lost+found at the top.
mkdir -p /data/storage
chown nonroot:nonroot /data/storage

# Sessions and webhook signatures are signed with this key, so it has to
# survive redeploys: generated once onto the volume. A key set in
# LAGO_RSA_PRIVATE_KEY (base64 PEM, as upstream documents it) wins.
if [ -z "${LAGO_RSA_PRIVATE_KEY:-}" ]; then
  key=/data/rsa_private.pem
  [ -s "$key" ] || ruby -ropenssl -e 'print OpenSSL::PKey::RSA.new(2048).to_pem' > "$key"
  chmod 600 "$key"
  export LAGO_RSA_PRIVATE_KEY=$(base64 -w0 "$key")
fi

until psql "$DATABASE_URL" -qtAc 'select 1' >/dev/null 2>&1; do echo "waiting for Postgres"; sleep 2; done

# Drop to the image's nonroot user (65532); busybox setpriv can't switch users.
# exec, so a backgrounded call's $! is the Lago process itself and gets the TERM.
as_lago() {
  HOME=/home/nonroot exec ruby -e 'Process.groups = [65532]; Process::GID.change_privilege(65532)
    Process::UID.change_privilege(65532); exec(*ARGV)' "$@"
}

# Migrations, predefined roles, and the admin account when LAGO_CREATE_ORG=true
# (idempotent: an existing user keeps the password they changed it to).
(as_lago ./scripts/migrate.sh)

pids=()
as_lago ./scripts/start.api.sh & pids+=($!)
as_lago ./scripts/start.worker.sh & pids+=($!)
as_lago ./scripts/start.clock.sh & pids+=($!)

# Redeploys send TERM: pass it on so Sidekiq finishes or requeues its jobs.
trap 'kill -TERM "${pids[@]}" 2>/dev/null; wait; exit 0' TERM INT
wait -n
echo "a Lago process exited; stopping so Railway restarts the container"
kill -TERM "${pids[@]}" 2>/dev/null || true
wait
exit 1
