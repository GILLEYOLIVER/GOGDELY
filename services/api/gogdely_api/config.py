"""Environment-driven settings for the GOGDELY API.

Keeps the local SQLite pilot as the default while making the service ready for
future hosting (Render or equivalent) and a managed database (Supabase
PostgreSQL or equivalent). No secret values live in the repository; every
deployment-specific value arrives through environment variables.

GOG-073/077/114 (prepared, not deployed): the production database is not
configured here — the local demo flow remains the only implemented backend.
"""
import os


class ApiConfig:
    """Reads settings once per process. Defaults match the local laboratory."""

    def __init__(self) -> None:
        self.environment = self._value("GOGDELY_ENV", "local")
        self.local_demo_enabled = self._value("GOGDELY_LOCAL_DEMO", "1") == "1"
        self.sqlite_path = self._value("GOGDELY_LOCAL_DB", ".local/gogdely.sqlite3")
        # Future managed PostgreSQL/Supabase connection string (not used by the
        # local demo). Example: postgresql://user:pass@host:5432/gogdely
        self.database_url = os.environ.get("GOGDELY_DATABASE_URL", "")
        # Comma-separated extra CORS origins for hosted frontends, e.g.
        # https://app.gogdely.example. Localhost is always allowed.
        self.cors_extra_origins = [
            origin.strip()
            for origin in os.environ.get("GOGDELY_CORS_ORIGINS", "").split(",")
            if origin.strip()
        ]
        # SEO (GOG-020/026 public-ready pages): absolute public base URL. Only
        # when set do pages become indexable, canonical, OG/JSON-LD enabled,
        # and do robots.txt/sitemap.xml advertise the public pages.
        self.public_base_url = os.environ.get("GOGDELY_PUBLIC_BASE_URL", "").rstrip("/")
        # HTTPS is mandatory in production by default; opt-in elsewhere.
        self.require_https = self._value(
            "GOGDELY_REQUIRE_HTTPS", "1" if self.environment == "production" else "0") == "1"
        # Google Search Console ownership token (external configuration).
        self.gsc_verification = os.environ.get("GOGDELY_GSC_VERIFICATION", "")

    @staticmethod
    def _value(name: str, default: str) -> str:
        value = os.environ.get(name, "")
        return value if value else default

    @property
    def uses_managed_database(self) -> bool:
        return bool(self.database_url)

    @property
    def public_web(self) -> bool:
        """True only when a public base URL is configured for SEO."""
        return bool(self.public_base_url)


config = ApiConfig()
