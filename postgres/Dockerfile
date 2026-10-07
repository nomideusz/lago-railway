# Postgres with pg_partman, which Lago's schema loads on first migration.
# Upstream's own getlago/postgres-partman image is PostgreSQL 15.0.
FROM postgres:17.9-trixie
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-17-partman \
 && rm -rf /var/lib/apt/lists/*
