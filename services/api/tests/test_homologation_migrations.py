"""Guardrails for main-branch, fictitious Supabase migration automation."""

from pathlib import Path

import pytest

from gogdely_api.homologation_migrations import (
    EXPECTED_SERVICE, MIGRATIONS, assert_target, migration_files, sql_body,
)


URL = "postgresql://postgres.vlcssgerbhbvekukpzki:example@aws-1-sa-east-1.pooler.supabase.com:5432/postgres"
ENV = {
    "RENDER": "true",
    "RENDER_GIT_BRANCH": "main",
    "RENDER_SERVICE_ID": EXPECTED_SERVICE,
    "GOGDELY_ENV": "testes",
}


def test_migration_target_requires_exact_branch_service_and_project():
    assert_target(URL, ENV)
    assert_target(URL, ENV | {"RENDER_GIT_BRANCH": "develop"})
    for changed in (
        {"RENDER_GIT_BRANCH": "feature/unreviewed"},
        {"RENDER_SERVICE_ID": "srv-unrelated"},
        {"GOGDELY_ENV": "production"},
    ):
        with pytest.raises(RuntimeError, match="target mismatch"):
            assert_target(URL, ENV | changed)
    with pytest.raises(RuntimeError, match="target mismatch"):
        assert_target(URL.replace("vlcssgerbhbvekukpzki", "different"), ENV)


def test_reviewed_migrations_are_sequential_and_transaction_wrapped():
    files = migration_files()
    assert [path.name[:4] for path in files] == [f"{n:04d}" for n in range(2, 8)]
    for path in files:
        body, digest = sql_body(path)
        assert "BEGIN;" not in body.splitlines()
        assert "COMMIT;" not in body.splitlines()
        assert len(digest) == 64


def test_unreviewed_transaction_shape_fails(tmp_path: Path):
    path = tmp_path / "0008_bad.sql"
    path.write_text("CREATE TABLE example (id integer);", encoding="utf-8")
    with pytest.raises(RuntimeError, match="wrapper"):
        sql_body(path)
