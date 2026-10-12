"""The theme is stored on the host and applies to every app; light or dark mode is per device."""

import json
from pathlib import Path

from starlette.testclient import TestClient

from mydata.service.api import create_app
from mydata.service.appearance import DEFAULT_THEME, THEMES
from mydata.service.assistant import Assistant
from mydata.service.auth import AgentStore, Authenticator
from mydata.service.config import Settings
from mydata.service.state import HostState

from service_helpers import ASSISTANT_TOKEN, TOKEN, ReadyModels, spied_registry

DESIGN_THEMES = Path(__file__).resolve().parents[2] / "design" / "themes.json"


def _app(tmp_path):
    registry, _ = spied_registry()
    auth = Authenticator({"mydata": TOKEN, "myassistant": ASSISTANT_TOKEN}, AgentStore(tmp_path))
    app = create_app(auth, registry, ReadyModels(), Assistant(Settings(home=tmp_path), registry),
                     state=HostState(tmp_path))
    return TestClient(app, base_url="http://127.0.0.1"), auth


def _h(t):
    return {"Authorization": f"Bearer {t}"}


def test_themes_match_the_design_files():
    design = json.loads(DESIGN_THEMES.read_text())["themes"]
    assert [(t["id"], t["name"]) for t in design] == list(THEMES)
    assert [t["id"] for t in design if t.get("default")] == [DEFAULT_THEME]


def test_default_theme_is_kiwi_in_status_and_get(tmp_path):
    c, _ = _app(tmp_path)
    assert c.get("/status", headers=_h(TOKEN)).json()["theme"] == "kiwi"
    r = c.get("/appearance", headers=_h(ASSISTANT_TOKEN))
    assert r.status_code == 200 and r.json()["theme"] == "kiwi"


def test_get_lists_six_themes_in_order(tmp_path):
    c, _ = _app(tmp_path)
    themes = c.get("/appearance", headers=_h(TOKEN)).json()["themes"]
    assert themes == [{"id": "kiwi", "name": "Kiwi"}, {"id": "graphite", "name": "Graphite"},
                      {"id": "dusk", "name": "Dusk"}, {"id": "plum", "name": "Plum"},
                      {"id": "rose", "name": "Rose"}, {"id": "amber", "name": "Amber"}]


def test_put_persists_shows_in_status_and_survives_a_restart(tmp_path):
    c, _ = _app(tmp_path)
    r = c.put("/appearance", json={"theme": "dusk"}, headers=_h(TOKEN))
    assert r.status_code == 200 and r.json()["theme"] == "dusk" and len(r.json()["themes"]) == 6
    # another app, polling /status, sees the change
    assert c.get("/status", headers=_h(ASSISTANT_TOKEN)).json()["theme"] == "dusk"
    assert c.get("/appearance", headers=_h(ASSISTANT_TOKEN)).json()["theme"] == "dusk"
    # a new HostState on the same folder (a restarted host) reads it back
    assert HostState(tmp_path).theme == "dusk"
    c2, _ = _app(tmp_path)
    assert c2.get("/status", headers=_h(TOKEN)).json()["theme"] == "dusk"


def test_theme_and_assistant_switch_do_not_overwrite_each_other(tmp_path):
    c, _ = _app(tmp_path)
    c.put("/appearance", json={"theme": "plum"}, headers=_h(TOKEN))
    c.put("/assistant/settings", json={"enabled": False}, headers=_h(TOKEN))
    s = HostState(tmp_path)
    assert s.theme == "plum" and s.assistant_enabled is False


def test_unknown_theme_is_400_and_changes_nothing(tmp_path):
    c, _ = _app(tmp_path)
    c.put("/appearance", json={"theme": "rose"}, headers=_h(TOKEN))
    r = c.put("/appearance", json={"theme": "neon"}, headers=_h(TOKEN))
    assert r.status_code == 400
    detail = r.json()["detail"]
    assert "neon" in detail and all(t in detail for t, _ in THEMES)
    assert HostState(tmp_path).theme == "rose"
    assert c.get("/status", headers=_h(TOKEN)).json()["theme"] == "rose"


def test_agent_tokens_cannot_read_or_set_the_theme(tmp_path):
    c, auth = _app(tmp_path)
    _, agent = auth.agents.create("x")
    assert c.get("/appearance", headers=_h(agent)).status_code == 403
    assert c.put("/appearance", json={"theme": "amber"}, headers=_h(agent)).status_code == 403
    assert HostState(tmp_path).theme == "kiwi"


def test_hand_edited_unknown_theme_reads_as_default(tmp_path):
    (tmp_path / "state.json").write_text(json.dumps({"theme": "neon", "assistant_enabled": False}))
    assert HostState(tmp_path).theme == "kiwi"
