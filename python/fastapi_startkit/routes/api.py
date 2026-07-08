from starlette.responses import PlainTextResponse


async def index():
    return PlainTextResponse(content="")


async def get_user(id: int):
    return PlainTextResponse(content=f"{id}".encode())


async def create_user():
    return PlainTextResponse(content="")
