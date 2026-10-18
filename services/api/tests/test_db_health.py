"""No external database access in unit tests."""

import ssl

from gogdely_api import db_health


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
