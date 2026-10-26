"""No external database access in unit tests."""

import ssl

import pg8000
import scramp

from gogdely_api import db_health


def test_pg8000_scramp_channel_binding_api_is_available() -> None:
    # pg8000 1.31.5 uses this API; scramp 1.5.0 removed it.
    assert callable(scramp.make_channel_binding)


def test_rejects_invalid_database_urls() -> None:
    assert not db_health.foundation_ready("")
    assert not db_health.foundation_ready("http://user:password@db.test/postgres")
    assert not db_health.foundation_ready("postgresql://user@db.test/postgres")
    assert not db_health.foundation_ready("postgresql://user:password@db.test:bad/postgres")


def test_queries_for_forced_rls_with_verified_tls(monkeypatch) -> None:
    captured = {}

    class Connection:
        def __init__(self, **kwargs):
            captured.update(kwargs)

        def run(self, sql):
            assert "c.relrowsecurity AND c.relforcerowsecurity" in sql
            return [[8]]

        def close(self):
            captured["closed"] = True

    monkeypatch.setattr(db_health.pg8000.native, "Connection", Connection)
    assert db_health.foundation_ready("postgresql://gog%40test:p%40ss@db.test:6543/postgres")
    assert captured["user"] == "gog@test"
    assert captured["password"] == "p@ss"
    assert captured["port"] == 6543
    assert captured["ssl_context"].verify_mode == ssl.CERT_REQUIRED
    assert captured["ssl_context"].check_hostname
    assert captured["closed"]


def test_supabase_pooler_keeps_verified_tls_without_strict_flag(monkeypatch) -> None:
    captured = {}

    class Connection:
        def __init__(self, **kwargs):
            captured.update(kwargs)

        def run(self, sql):
            return [[8]]

        def close(self):
            pass

    monkeypatch.setattr(db_health.pg8000.native, "Connection", Connection)
    assert db_health.foundation_ready(
        "postgresql://user:password@aws-1-sa-east-1.pooler.supabase.com/postgres"
    )
    tls = captured["ssl_context"]
    assert tls.verify_mode == ssl.CERT_REQUIRED
    assert tls.check_hostname
    assert not (tls.verify_flags & ssl.VERIFY_X509_STRICT)


def test_readiness_logs_only_failure_class(monkeypatch, caplog) -> None:
    class Connection:
        def __init__(self, **kwargs):
            raise pg8000.InterfaceError("password=private-value")

    import pg8000

    monkeypatch.setattr(db_health.pg8000.native, "Connection", Connection)
    assert not db_health.foundation_ready(
        "postgresql://user:private-value@db.test/postgres"
    )
    assert "InterfaceError" in caplog.text
    assert "private-value" not in caplog.text


def test_database_error_logs_only_valid_sqlstate(monkeypatch, caplog) -> None:
    class Connection:
        def __init__(self, **kwargs):
            raise pg8000.DatabaseError({"C": "28P01", "M": "password=private-value"})

    monkeypatch.setattr(db_health.pg8000.native, "Connection", Connection)
    assert not db_health.foundation_ready("postgresql://user:private-value@db.test/postgres")
    assert "SQLSTATE: 28P01" in caplog.text
    assert "private-value" not in caplog.text
