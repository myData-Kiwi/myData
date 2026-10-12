"""While the tools serve fake data, the host's today is pinned to the demo date (on by default, logged)."""

import asyncio
import json
from datetime import date

import httpx
import httpx2
import pytest
from mcp import Client
from mcp.client.streamable_http import streamable_http_client

from mydata.service.api import create_app
from mydata.service.assistant import Assistant
from mydata.service.auth import AgentStore, Authenticator
from mydata.service.config import DEFAULT_CONFIG, ConfigError, load_settings
from mydata.tools import default_registry

from service_helpers import TOKEN, ReadyModels, serve

DEMO = date(2026, 3, 18)


def _settings(tmp_path, text):
    (tmp_path / "config.toml").write_text(text)
    return load_settings(tmp_path)


def test_pinned_by_default(tmp_path):
    assert _settings(tmp_path, DEFAULT_CONFIG).today() == DEMO


def test_config_written_before_the_setting_is_still_pinned(tmp_path):
    old = DEFAULT_CONFIG[: DEFAULT_CONFIG.index("[dev]")]
    assert _settings(tmp_path, old).pin_today == DEMO


def test_can_be_switched_off(tmp_path):
    s = _settings(tmp_path, DEFAULT_CONFIG.replace('pin_today = "2026-03-18"', "pin_today = false"))
    assert s.pin_today is None and s.today() == date.today()


@pytest.mark.parametrize("bad", ['pin_today = "next week"', "pin_today = 5", "pin_today = true"])
def test_bad_values_are_refused(tmp_path, bad):
    with pytest.raises(ConfigError):
        _settings(tmp_path, DEFAULT_CONFIG.replace('pin_today = "2026-03-18"', bad))


def _app(tmp_path):
    settings = _settings(tmp_path, DEFAULT_CONFIG)
    registry = default_registry(today=settings.today)
    auth = Authenticator({"mydata": TOKEN}, AgentStore(tmp_path))
    return create_app(auth, registry, ReadyModels(), Assistant(settings, registry, today=settings.today))


def test_mcp_and_status_use_the_pinned_date(tmp_path):
    app = _app(tmp_path)

    async def go(base):
        async with httpx2.AsyncClient(headers={"Authorization": f"Bearer {TOKEN}"}) as http:
            async with Client(streamable_http_client(f"{base}/mcp", http_client=http)) as c:
                return await c.call_tool("list_events", {"date": "tomorrow"})

    with serve(app) as (base, _):
        res = json.loads(asyncio.run(go(base)).content[0].text)
        st = httpx.get(f"{base}/status", headers={"Authorization": f"Bearer {TOKEN}"}).json()
    assert res["result"]["from"] == "2026-03-19"
    assert any(e["title"] == "Personal training" for e in res["result"]["events"])
    assert st["today"] == "2026-03-18" and st["demo_date"] is True
