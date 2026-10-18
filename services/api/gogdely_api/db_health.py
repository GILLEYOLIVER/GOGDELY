"""Read-only PostgreSQL readiness check for the managed environment."""

import logging
import re
import ssl
from importlib.resources import files
from urllib.parse import unquote, urlsplit

import pg8000.native

logger = logging.getLogger(__name__)


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
        tls = ssl.create_default_context()
        tls.load_verify_locations(
            cafile=str(files("gogdely_api").joinpath("certs", "prod-ca-2021.crt"))
        )
        if parsed.hostname.endswith(".pooler.supabase.com"):
            # Supabase's shared pooler currently serves an intermediate CA
            # without Key Usage. Python 3.13+ rejects it under X509_STRICT
            # (OpenSSL error 92). Keep CA and hostname verification enabled.
            tls.verify_flags &= ~ssl.VERIFY_X509_STRICT
        connection = pg8000.native.Connection(
            user=unquote(parsed.username),
            password=unquote(parsed.password),
            host=parsed.hostname,
            port=port,
            database=database,
            ssl_context=tls,
            timeout=3,
            application_name="gogdely-readiness",
        )
        rows = connection.run(
            """SELECT count(*) FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'gogdely' AND c.relkind = 'r'
                 AND c.relrowsecurity AND c.relforcerowsecurity"""
        )
        ready = bool(rows and rows[0][0] == 8)
        if not ready:
            logger.warning("database foundation schema is incomplete")
        return ready
    except ssl.SSLCertVerificationError as exc:
        # The verification code identifies CA and hostname failures without
        # logging the connection string, credential, or driver exception text.
        logger.warning("database TLS verification failed: code=%s", exc.verify_code)
        return False
    except pg8000.DatabaseError as exc:
        # pg8000 stores PostgreSQL ErrorResponse fields in args[0]. Emit only
        # the validated five-character SQLSTATE, never server message fields.
        fields = exc.args[0] if exc.args else None
        code = fields.get("C") if isinstance(fields, dict) else None
        safe_code = code if isinstance(code, str) and re.fullmatch(r"[0-9A-Z]{5}", code) else "unknown"
        logger.warning("database readiness SQLSTATE: %s", safe_code)
        return False
    except (OSError, ValueError, pg8000.Error) as exc:
        # Never log exception text: drivers can include connection details.
        logger.warning("database readiness connection failed: %s", type(exc).__name__)
        return False
    finally:
        if connection is not None:
            connection.close()
