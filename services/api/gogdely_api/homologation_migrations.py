"""Apply reviewed SQL only to the isolated, fictitious GOGDELY project.

The Render Free plan has no pre-deploy command.  This command runs before
uvicorn in the start command; any failure prevents the new API from going live.
It is deliberately unavailable for production databases.
"""

from __future__ import annotations

import hashlib
import logging
import os
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

from gogdely_api.db_health import configured_database_url, connect_database


log = logging.getLogger(__name__)
ROOT = Path(__file__).resolve().parents[3]
MIGRATIONS = ROOT / "database" / "migrations"
CHECKS = ROOT / "database" / "checks"
SEEDS = ROOT / "database" / "seeds"
PROJECT_REF = "vlcssgerbhbvekukpzki"
TENANT_ID = "c95d5aca-8eea-4ad4-8b50-53117abe3f01"
EXPECTED_SERVICE = "srv-dba163mq1p3s739u6k00"
_TRANSACTION_LINE = re.compile(r"(?im)^\s*(BEGIN|COMMIT);\s*$")


def assert_target(database_url: str, environ: dict[str, str]) -> None:
    """Fail before opening a connection unless every target identifier agrees."""
    parsed = urlsplit(database_url)
    if not (
        environ.get("RENDER") == "true"
        and environ.get("RENDER_GIT_BRANCH") in {"develop", "main"}
        and environ.get("RENDER_SERVICE_ID") == EXPECTED_SERVICE
        and environ.get("GOGDELY_ENV") in {"testes", "homologacao"}
        and parsed.scheme in {"postgres", "postgresql"}
        and parsed.hostname == "aws-1-sa-east-1.pooler.supabase.com"
        and unquote(parsed.username or "") == f"postgres.{PROJECT_REF}"
        and unquote(parsed.path.lstrip("/")) == "postgres"
        and parsed.port in {None, 5432}
    ):
        raise RuntimeError("homologation migration target mismatch")


def sql_body(path: Path) -> tuple[str, str]:
    """Require one reviewed transaction wrapper and preserve the SQL body."""
    raw = path.read_text(encoding="utf-8")
    wrappers = _TRANSACTION_LINE.findall(raw)
    if [item.upper() for item in wrappers] != ["BEGIN", "COMMIT"]:
        raise RuntimeError(f"invalid transaction wrapper: {path.name}")
    if re.search(r"(?im)^\s*ROLLBACK\s*;", raw):
        raise RuntimeError(f"rollback in migration: {path.name}")
    return _TRANSACTION_LINE.sub("", raw), hashlib.sha256(raw.encode()).hexdigest()


def migration_files() -> list[Path]:
    files = sorted(MIGRATIONS.glob("[0-9][0-9][0-9][0-9]_*.sql"))
    selected = [path for path in files if int(path.name[:4]) >= 2]
    versions = [int(path.name[:4]) for path in selected]
    if versions != list(range(2, max(versions, default=1) + 1)):
        raise RuntimeError("migration numbers are missing or duplicated")
    return selected


def _counts(connection) -> tuple[int, int, int, int, int, int, int, int, int]:
    return tuple(connection.run("""
        SELECT (SELECT count(*) FROM auth.users),
               (SELECT count(*) FROM gogdely.tenants),
               (SELECT count(*) FROM gogdely.branches),
               (SELECT count(*) FROM gogdely.memberships),
               (SELECT count(*) FROM gogdely.menu_items),
               (SELECT count(*) FROM gogdely.orders),
               (SELECT count(*) FROM pg_policies WHERE schemaname='gogdely'),
               (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='gogdely' AND c.relkind='r'),
               (SELECT count(*) FROM gogdely.tenants WHERE tenant_id='""" + TENANT_ID + """')
    """)[0])


def _apply(connection, files: list[Path]) -> None:
    connection.run("BEGIN")
    try:
        connection.run("SELECT pg_advisory_xact_lock(41041, 20261025)")
        ledger = connection.run("SELECT to_regclass('gogdely.schema_migrations') IS NOT NULL")[0][0]
        if not ledger:
            if _counts(connection) != (1, 1, 1, 1, 12, 0, 0, 8, 1):
                raise RuntimeError("homologation preflight did not match fictitious baseline")
            snapshot, _ = sql_body(CHECKS / "2026-10-25_homologacao_internal_snapshot.sql")
            connection.run(snapshot)
            connection.run("""CREATE TABLE gogdely.schema_migrations (
                version integer PRIMARY KEY,
                filename text NOT NULL UNIQUE,
                sha256 char(64) NOT NULL,
                applied_at timestamptz NOT NULL DEFAULT now()
            )""")
            connection.run("ALTER TABLE gogdely.schema_migrations ENABLE ROW LEVEL SECURITY")
            connection.run("ALTER TABLE gogdely.schema_migrations FORCE ROW LEVEL SECURITY")
            connection.run("REVOKE ALL ON gogdely.schema_migrations FROM PUBLIC, anon, authenticated")
            bootstrap = True
        else:
            bootstrap = False
        applied = {row[0]: (row[1], row[2]) for row in connection.run(
            "SELECT version, filename, sha256 FROM gogdely.schema_migrations ORDER BY version"
        )}
        if not bootstrap and any(version not in {int(path.name[:4]) for path in files} for version in applied):
            raise RuntimeError("database has an unknown migration version")
        for path in files:
            version = int(path.name[:4])
            body, digest = sql_body(path)
            if version in applied:
                if applied[version] != (path.name, digest):
                    raise RuntimeError(f"migration checksum changed: {version:04d}")
                continue
            if applied and version != max(applied) + 1:
                raise RuntimeError("migration order is not contiguous")
            connection.run(body)
            connection.run(
                "INSERT INTO gogdely.schema_migrations(version,filename,sha256) VALUES (:v,:f,:h)",
                v=version, f=path.name, h=digest,
            )
            applied[version] = (path.name, digest)
            log.info("applied homologation migration %04d", version)
        if bootstrap:
            seed, _ = sql_body(SEEDS / "2026-10-25_entrega_ficticia.sql")
            connection.run(seed)
        if bootstrap:
            if _counts(connection)[0:5] != (1, 1, 1, 1, 12):
                raise RuntimeError("homologation postflight counts changed")
            if connection.run("SELECT count(*) FROM gogdely.courier_memberships WHERE tenant_id='" + TENANT_ID + "' AND active")[0][0] != 1:
                raise RuntimeError("fictitious courier seed missing")
        connection.run("COMMIT")
    except Exception:
        connection.run("ROLLBACK")
        raise


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    database_url = configured_database_url()
    assert_target(database_url, os.environ)
    files = migration_files()
    if not files:
        raise RuntimeError("no migrations found")
    connection = None
    try:
        connection = connect_database(database_url, "gogdely-homologation-migrations")
        _apply(connection, files)
    except Exception as exc:
        # Driver messages may contain credentials or row data; log type only.
        log.error("homologation migration stopped: %s", type(exc).__name__)
        raise SystemExit(1) from None
    finally:
        if connection is not None:
            connection.close()
    log.info("homologation migrations ready through %04d", int(files[-1].name[:4]))


if __name__ == "__main__":
    main()
