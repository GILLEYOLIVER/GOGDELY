"""Read-only PostgreSQL readiness check for the managed environment."""

import ssl
from urllib.parse import unquote, urlsplit

import pg8000.native


def foundation_ready(database_url: str) -> bool:
    """Require a reachable database and the eight isolated foundation tables.

    This does not claim that orders, Auth, Storage or payments are operational.
    The connection string and database exception are never returned to clients.
    """
    parsed = urlsplit(database_url)
    if parsed.scheme not in ("postgres", "postgresql") or not parsed.hostname:
        return False
    if parsed.username is None or parsed.password is None:
        return False
    database = unquote(parsed.path.lstrip("/"))
    if not database:
        return False

    try:
        port = parsed.port or 5432
    except ValueError:
        return False

    connection = None
    try:
        connection = pg8000.native.Connection(
            user=unquote(parsed.username),
            password=unquote(parsed.password),
            host=parsed.hostname,
            port=port,
            database=database,
            ssl_context=ssl.create_default_context(),
            timeout=3,
            application_name="gogdely-readiness",
        )
        rows = connection.run(
            """SELECT count(*) FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'gogdely' AND c.relkind = 'r'
                 AND c.relrowsecurity AND c.relforcerowsecurity"""
        )
        return bool(rows and rows[0][0] == 8)
    except (OSError, ValueError, pg8000.Error):
        return False
    finally:
        if connection is not None:
            connection.close()
