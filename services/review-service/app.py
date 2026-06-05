from __future__ import annotations

import json
import os
import threading
import uuid
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse


DEFAULT_PRODUCT_ID = "OLJCESPC7Z"
SERVICE_NAME = "review-service"

_reviews_lock = threading.Lock()
_reviews: list[dict[str, Any]] = [
    {
        "id": "seed-1",
        "product_id": DEFAULT_PRODUCT_ID,
        "user_name": "alice",
        "rating": 5,
        "content": "Great product for demo checkout flows.",
        "created_at": "2026-06-03T00:00:00Z",
    },
    {
        "id": "seed-2",
        "product_id": DEFAULT_PRODUCT_ID,
        "user_name": "bob",
        "rating": 4,
        "content": "Looks good in the Online Boutique demo.",
        "created_at": "2026-06-03T00:05:00Z",
    },
]


def _utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _json_bytes(payload: Any) -> bytes:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def _summary(product_id: str | None) -> dict[str, Any]:
    with _reviews_lock:
        selected = [item for item in _reviews if product_id is None or item["product_id"] == product_id]

    distribution = {str(score): 0 for score in range(1, 6)}
    for item in selected:
        distribution[str(item["rating"])] += 1

    total = len(selected)
    average = round(sum(item["rating"] for item in selected) / total, 2) if total else 0
    return {
        "product_id": product_id,
        "review_count": total,
        "average_rating": average,
        "rating_distribution": distribution,
    }


def _validate_review(payload: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    product_id = str(payload.get("product_id", "")).strip()
    content = str(payload.get("content", "")).strip()
    user_name = str(payload.get("user_name", "anonymous")).strip() or "anonymous"

    if not product_id:
        return None, "product_id is required"
    if not content:
        return None, "content is required"

    try:
        rating = int(payload.get("rating"))
    except (TypeError, ValueError):
        return None, "rating must be an integer from 1 to 5"
    if rating < 1 or rating > 5:
        return None, "rating must be an integer from 1 to 5"

    return {
        "id": str(uuid.uuid4()),
        "product_id": product_id,
        "user_name": user_name,
        "rating": rating,
        "content": content,
        "created_at": _utc_now(),
    }, None


class ReviewHandler(BaseHTTPRequestHandler):
    server_version = f"{SERVICE_NAME}/0.1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        if parsed.path == "/healthz":
            self._send_json({"status": "ok", "service": SERVICE_NAME})
            return

        if parsed.path == "/reviews":
            product_id = params.get("product_id", [None])[0]
            with _reviews_lock:
                reviews = [item for item in _reviews if product_id is None or item["product_id"] == product_id]
            self._send_json({"reviews": reviews, "count": len(reviews)})
            return

        if parsed.path == "/reviews/summary":
            product_id = params.get("product_id", [None])[0]
            self._send_json(_summary(product_id))
            return

        if parsed.path == "/metrics":
            self._send_text(self._metrics(), content_type="text/plain; version=0.0.4")
            return

        self._send_json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/reviews":
            self._send_json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        except (ValueError, json.JSONDecodeError):
            self._send_json({"error": "invalid JSON body"}, status=HTTPStatus.BAD_REQUEST)
            return

        review, error = _validate_review(payload)
        if error:
            self._send_json({"error": error}, status=HTTPStatus.BAD_REQUEST)
            return

        with _reviews_lock:
            _reviews.append(review)
        self._send_json(review, status=HTTPStatus.CREATED)

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._send_common_headers("application/json")
        self.end_headers()

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"{self.address_string()} - {fmt % args}", flush=True)

    def _send_json(self, payload: Any, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = _json_bytes(payload)
        self.send_response(status)
        self._send_common_headers("application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, body: str, content_type: str) -> None:
        encoded = body.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self._send_common_headers(content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def _send_common_headers(self, content_type: str) -> None:
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _metrics(self) -> str:
        with _reviews_lock:
            reviews = list(_reviews)
        product_ids = sorted({item["product_id"] for item in reviews})
        lines = [
            "# HELP review_service_reviews_total Total number of reviews.",
            "# TYPE review_service_reviews_total gauge",
            f"review_service_reviews_total {len(reviews)}",
            "# HELP review_service_average_rating Average rating by product.",
            "# TYPE review_service_average_rating gauge",
        ]
        for product_id in product_ids:
            item_summary = _summary(product_id)
            lines.append(
                f'review_service_average_rating{{product_id="{product_id}"}} '
                f'{item_summary["average_rating"]}'
            )
        return "\n".join(lines) + "\n"


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), ReviewHandler)
    print(f"{SERVICE_NAME} listening on 0.0.0.0:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
