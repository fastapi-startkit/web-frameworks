# FastAPI vs FastAPI-StartKit (Python benchmark)

Two Python ASGI entries in this harness implement the **same three benchmark
routes** with identical handlers (`GET /` → empty, `GET /user/{id}` → the id as
plain text, `POST /user` → empty). This document compares them.

## Overview

| | **fastapi** | **fastapi-startkit** |
|---|---|---|
| What it is | The raw [FastAPI](https://fastapi.tiangolo.com) micro-framework (Starlette + Pydantic). | A batteries-included application framework built **on top of** FastAPI (Laravel-style providers / config / service container). |
| Benchmark app | A single `FastAPI()` instance in `server.py` with three route handlers. | An `Application` booted with a `FastAPIProvider`; the same three routes are registered through the framework's router (`providers/`, `config/`, `bootstrap/`). |
| Directory | `python/fastapi` | `python/fastapi_startkit` |

Both wrap the same underlying FastAPI / Starlette request path — `fastapi-startkit`
adds a thin framework layer around it.

## Correctness

Both pass the shared route spec (`.spec/route_spec.rb`) **6/6**, verified through
the standard Docker + rspec harness and confirmed in-container:

| Route | Expected | fastapi | fastapi-startkit |
|---|---|---|---|
| `GET /` | `200`, empty body | ✅ | ✅ |
| `GET /user/0` | `200`, body `0` | ✅ | ✅ |
| `POST /user` | `200`, empty body | ✅ | ✅ |

## Setup / dependencies

| | **fastapi** | **fastapi-startkit** |
|---|---|---|
| Declared dependency | `fastapi>=0.139,<0.140` | `fastapi-startkit[fastapi]==0.47.0` |
| Underlying FastAPI | `0.139.0` | `0.139.0` (transitive, via `fastapi-startkit==0.47.0`) |
| App composition | single `FastAPI()` in `server.py` | `Application` + `FastAPIProvider` (providers / config / bootstrap) |
| Engines | uvicorn (default), hypercorn, daphne, granian | uvicorn (default), hypercorn, daphne, granian |
| Default build | `.Dockerfile.uvicorn` | `.Dockerfile.uvicorn` |
| Python | 3.14 | 3.14 |

The `fastapi-startkit` dependency is pinned to `==0.47.0`, which resolves the
**same FastAPI 0.139.0 / Starlette 1.3.1** the baseline uses, so both Python
entries benchmark on an identical FastAPI/Starlette stack; both are built and run
from the same default `.Dockerfile.uvicorn` engine.

## Performance

**Relative, same-host comparison — NOT official benchmark figures.**

Method (verbatim):

> macOS + Docker (OrbStack, engine 28.3.3); Docker `python:3.14-slim`; uvicorn
> `--workers=nproc` (11 workers); load = `oha 1.14.0`, **keep-alive enabled**
> (harness default as of the `--disable-keepalive` removal), `--latency-correction`,
> `--wait-ongoing-requests-after-deadline`; 8s × 3 reps averaged; concurrency 64
> and 256; 100% success every cell. Matched stack both sides: Python 3.14,
> fastapi 0.139.0, starlette 1.3.1 (`fastapi_startkit` built from
> fastapi-startkit 0.47.0).

Relative delta (fastapi-startkit vs fastapi; negative = fastapi-startkit slower):

| Route | Δ @ c64 | Δ @ c256 |
|---|---|---|
| `GET /` | −8.5% | −9.0% |
| `GET /user/0` | −11.6% | −11.9% |
| `POST /user` | −12.6% | −11.0% |

Absolute throughput (host-specific, for context only):

| Route | fastapi (c64 / c256) | fastapi-startkit (c64 / c256) |
|---|---|---|
| `GET /` | 60.1k / 65.5k rps | 55.0k / 59.6k rps |
| `GET /user/0` | 54.9k / 50.7k rps | 48.5k / 44.7k rps |
| `POST /user` | 61.0k / 63.6k rps | 53.3k / 56.6k rps |

100% success across all cells.

### Reading these numbers

Unlike an earlier keepalive-only, hand-run comparison, this data shows a
**fairly consistent 8.5–12.6% overhead across every route**, not a pattern
where GET is "close" and only POST is meaningfully slower — all three routes
land in the same rough band once measured with the standard harness (keep-alive
now on by default). This is fastapi-startkit's provider/DI/router wiring cost
showing up per request, not a GET-vs-POST-specific effect.

**Do not read the individual route deltas as more precise than they are.** Even
within this single run, per-rep variance was substantial — e.g. `fastapi`
`GET /user/0` at c256 ranged from ~45.3k to ~59.2k rps across 3 reps on this
host (OrbStack on macOS is a known noisy environment for this kind of test).
The deltas above are averages of only 3 reps each; treat them as directional,
not authoritative. Authoritative absolute throughput/latency requires the
Linux harness (`run.sh` on Linux, ideally with more reps).

**These numbers are not "no overhead."** fastapi-startkit is measurably slower
than plain fastapi across every route on this host, by roughly 9–13%. That gap
is the cost of the framework's provider/service-container wiring sitting in
front of otherwise-identical FastAPI/Starlette handlers.
