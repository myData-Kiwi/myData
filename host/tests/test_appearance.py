"""The host's old theme: PUT /appearance is retired (410); GET and /status's `theme` stay for one release."""

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

DESIGN_THEMES = Path(__file__).resolve().parents[2] / "design" / "themes"

# Each old colour id and the built-in whose default palette it is now (design/themes/ARCHITECTURE.md 4.2).
HOMES = {"kiwi": "kiwi", "graphite": "hairline", "dusk": "frosted", "plum": "journal", "rose": "sticker",
         "amber": "paperback"}


def _app(tmp_path):
    registry, _ = spied_registry()
    auth = Authenticator({"mydata": TOKEN, "myassistant": ASSISTANT_TOKEN}, AgentStore(tmp_path))
    app = create_app(auth, registry, ReadyModels(), Assistant(Settings(home=tmp_path), registry),
                     state=HostState(tmp_path))
    return TestClient(app, base_url="http://127.0.0.1"), auth


def _h(t):
    return {"Authorization": f"Bearer {t}"}


def test_the_old_colours_are_palettes_of_the_design_files():
    # The host's list is frozen (devices read it once to seed their own choice); each colour lives on as the
    # default palette of the theme it moved to, under the same id and name.
    assert [t for t, _ in THEMES] == list(HOMES)
    assert DEFAULT_THEME == "kiwi"
    for colour, name in THEMES:
        theme = json.loads((DESIGN_THEMES / HOMES[colour] / "theme.json").read_text())
        assert theme["default-palette"] == colour
        assert [p["name"] for p in theme["palettes"] if p["id"] == colour] == [name]


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


def test_put_is_retired_with_410_and_changes_nothing(tmp_path):
    c, _ = _app(tmp_path)
    HostState(tmp_path).set_theme("plum")  # chosen on the host before themes moved to each device
    r = c.put("/appearance", json={"theme": "dusk"}, headers=_h(TOKEN))
    assert r.status_code == 410
    assert r.json()["detail"] == "Themes are chosen on each device now."
    # without a body too (the route takes none now)
    assert c.put("/appearance", headers=_h(TOKEN)).status_code == 410
    # the host's old theme stays readable for one release, so each device can seed its own choice
    assert HostState(tmp_path).theme == "plum"
    assert c.get("/status", headers=_h(ASSISTANT_TOKEN)).json()["theme"] == "plum"
    assert c.get("/appearance", headers=_h(ASSISTANT_TOKEN)).json()["theme"] == "plum"


def test_the_old_theme_routes_are_marked_deprecated_in_the_document():
    from mydata.service.openapi import openapi_document
    doc = openapi_document()
    assert doc["paths"]["/appearance"]["get"]["deprecated"] is True
    put = doc["paths"]["/appearance"]["put"]
    assert put["deprecated"] is True and "410" in put["responses"] and "requestBody" not in put
    assert doc["components"]["schemas"]["StatusOut"]["properties"]["theme"]["deprecated"] is True


def test_agent_tokens_cannot_read_or_set_the_theme(tmp_path):
    c, auth = _app(tmp_path)
    _, agent = auth.agents.create("x")
    assert c.get("/appearance", headers=_h(agent)).status_code == 403
    assert c.put("/appearance", json={"theme": "amber"}, headers=_h(agent)).status_code == 403
    assert HostState(tmp_path).theme == "kiwi"


def test_only_admin_apps_reach_the_retired_put(tmp_path):
    c, _ = _app(tmp_path)
    assert c.put("/appearance", headers=_h(ASSISTANT_TOKEN)).status_code == 403


def test_hand_edited_unknown_theme_reads_as_default(tmp_path):
    (tmp_path / "state.json").write_text(json.dumps({"theme": "neon", "assistant_enabled": False}))
    assert HostState(tmp_path).theme == "kiwi"


def test_chosen_says_whether_a_theme_was_ever_chosen_on_the_host(tmp_path):
    c, _ = _app(tmp_path)
    assert c.get("/appearance", headers=_h(TOKEN)).json()["chosen"] is False
    HostState(tmp_path).set_theme("kiwi")
    assert c.get("/appearance", headers=_h(TOKEN)).json()["chosen"] is True
