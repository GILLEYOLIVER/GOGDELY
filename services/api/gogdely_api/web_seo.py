"""Public web SEO infrastructure for the GOGDELY API.

GOG-020/026 public readiness: robots.txt, sitemap.xml, the og:image asset and
the Google Search Console verification file. In the laboratory (no
GOGDELY_PUBLIC_BASE_URL) robots.txt disallows everything and the sitemap is
empty — no page is exposed to search engines. When the owner configures a
public base URL, the same endpoints advertise the indexable table menus.

HTTPS (GOG-077): a middleware redirects plain HTTP to HTTPS and sets HSTS
when GOGDELY_REQUIRE_HTTPS=1 (default on in production), respecting the
X-Forwarded-Proto header set by hosting proxies such as Render.
"""
from fastapi import APIRouter, HTTPException, Request, Response
from fastapi.responses import PlainTextResponse, RedirectResponse
from pathlib import Path

from gogdely_api.config import config

router = APIRouter(include_in_schema=False)

_OG_IMAGE = Path(__file__).resolve().parent / "static" / "og-image.png"
_PILOT_TABLES = [f"M{index:02d}" for index in range(1, 11)]
_PILOT_STORE = "burger-house"


@router.get("/robots.txt", response_class=PlainTextResponse)
def robots_txt() -> PlainTextResponse:
    if not config.public_web:
        # Laboratory: nothing is public; every route stays out of crawlers.
        return PlainTextResponse("User-agent: *\nDisallow: /\n")
    lines = [
        "User-agent: *",
        "Allow: /",
        "Disallow: /api/",
        "Disallow: /docs",
        f"Sitemap: {config.public_base_url}/sitemap.xml",
    ]
    return PlainTextResponse("\n".join(lines) + "\n")


@router.get("/sitemap.xml")
def sitemap_xml() -> Response:
    urls = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"]
    if config.public_web:
        for table in _PILOT_TABLES:
            urls.append(
                f"<url><loc>{config.public_base_url}/m/{_PILOT_STORE}/{table}</loc>"
                "<changefreq>daily</changefreq></url>")
    urls.append("</urlset>")
    return Response(content="\n".join(urls), media_type="application/xml",
                    headers={"Cache-Control": "public, max-age=3600"})


@router.get("/og-image.png")
def og_image() -> Response:
    if not _OG_IMAGE.is_file():
        raise HTTPException(status_code=404, detail="og-image not found")
    return Response(content=_OG_IMAGE.read_bytes(), media_type="image/png",
                    headers={"Cache-Control": "public, max-age=86400, immutable"})


@router.get("/google{token}.html")
def gsc_verification(token: str) -> Response:
    """Google Search Console ownership proof; active only when the owner
    configures GOGDELY_GSC_VERIFICATION with the token provided by Google."""
    if not config.gsc_verification or token != config.gsc_verification:
        raise HTTPException(status_code=404, detail="Not found")
    return PlainTextResponse(f"google-site-verification: google{token}.html")


async def https_and_security_middleware(request: Request, call_next):
    """Production HTTPS enforcement and conservative security headers."""
    response = await call_next(request)
    forwarded_proto = request.headers.get("x-forwarded-proto", "")
    is_http = forwarded_proto == "http" or (
        not forwarded_proto and request.url.scheme == "http")
    if config.require_https and is_http:
        https_url = request.url.replace(scheme="https")
        redirect = RedirectResponse(str(https_url), status_code=308)
        redirect.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return redirect
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    if (request.url.scheme == "https" or forwarded_proto == "https") and config.require_https:
        response.headers.setdefault("Strict-Transport-Security",
                                    "max-age=31536000; includeSubDomains")
    return response
