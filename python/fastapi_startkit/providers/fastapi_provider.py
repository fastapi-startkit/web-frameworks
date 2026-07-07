from fastapi_startkit.fastapi import FastAPIProvider as BaseFastAPIProvider

from routes.api import public


class FastAPIProvider(BaseFastAPIProvider):
    def boot(self) -> None:
        # Register the benchmark routes first so they win route resolution over
        # anything the framework's boot chain may mount at "/" (e.g. a bundled
        # frontend or locale-prefix handler), which would otherwise shadow them.
        self.app.include_router(public)
        super().boot()
