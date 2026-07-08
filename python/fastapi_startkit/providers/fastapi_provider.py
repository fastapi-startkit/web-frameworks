from fastapi_startkit.fastapi import FastAPIProvider as BaseFastAPIProvider

from routes.api import create_user, get_user, index


class FastAPIProvider(BaseFastAPIProvider):
    def boot(self) -> None:
        super().boot()
        # Register routes directly on the app router instead of include_router.
        # FastAPI 0.139 keeps an included router as a nested _IncludedRouter node,
        # adding a per-request resolution layer; flat registration lands the routes
        # on app.router.routes for a single-pass match.
        fastapi = self.app.fastapi
        fastapi.add_api_route("/", index, methods=["GET"])
        fastapi.add_api_route("/user/{id}", get_user, methods=["GET"])
        fastapi.add_api_route("/user", create_user, methods=["POST"])
