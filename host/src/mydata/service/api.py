"""The host's HTTP API. Bound to localhost; every request needs the token (security.GuardMiddleware).

  GET  /status                 host version and API version, model state and download progress
  POST /assistant/messages     one user message; the reply streams as server-sent events
  GET  /approvals              approvals, optionally filtered by status
  GET  /approvals/{id}         one approval
  POST /approvals/{id}         approve or reject; approving runs exactly the held call, once
  PUT  /assistant/settings     switch the assistant on or off
  GET  /appearance             the theme every app uses, and the themes to choose from
  PUT  /appearance             set the theme every app uses (light or dark mode is per device, not here)
  POST /shutdown               stop the host (the myData app and the mydata command only)
  GET  /tools                  the tool registry
  GET  /agents                 agent tokens (never the tokens themselves), and which are connected
  POST /agents                 create an agent token; the token is returned once
  DELETE /agents/{id}          revoke an agent token
  GET  /accounts               linked accounts (never a password)
  POST /accounts               link an account; the password is verified with the provider first
  DELETE /accounts/{id}        unlink an account; its mirrored data and its Keychain item are deleted
                               (snapshots keep copies until they expire: backup.kept_until)
  POST /accounts/{id}/sync     sync the account now
  GET  /sync                   the mode (demo or real) and every account's sync status
  GET  /contacts               mirrored contacts, listed or searched
  GET  /contacts/{id}          one contact (the raw vCard only with ?raw=1)
  GET  /contacts/{id}/photo    the contact's photo (JPEG or PNG), or 404
  POST /contacts               create a contact the host owns (in its "myData" address book)
  PATCH /contacts/{id}         change an owned contact; If-Match with its etag is required
  DELETE /contacts/{id}        move an owned contact to Recently deleted (purged after 30 days); If-Match required
  GET  /trash                  what is in Recently deleted, and when each item is purged
  DELETE /trash/{id}           delete an item in Recently deleted for good now; If-Match required
  POST /trash/{id}/restore     bring an item back from Recently deleted
  POST /undo/{id}              undo one change (as a new change; refused if the item changed since), a merge too
  POST /contacts/merge         merge owned contacts into one (the originals go to Recently deleted; undo restores them)
  POST /import/contacts/preview              read a .vcf or .zip (the raw bytes) into a preview; nothing is written
  POST /import/contacts/from-source/{id}/preview   a preview of a copy of a followed iCloud account (never This Mac)
  GET  /import/previews/{id}   a preview again, as the host is now
  POST /import/previews/{id}/commit          import it as one batch, after a snapshot
  GET  /imports                the imports, newest first
  POST /imports/{id}/undo      undo a whole import (what was changed since is kept and reported)
  GET  /calendars              mirrored calendars
  GET  /events                 events between two dates, recurring ones expanded, and what each source holds
  GET  /sources                every source: This Mac (on a Mac host only) and the linked iCloud accounts
  PUT  /sources/mac            turn This Mac on or off; choose its accounts and calendars
  POST /sources/mac/request-access   show the system's permission prompt (the user pressed Allow)
  POST /sources/mac/sync       read the Mac's contacts and calendars again now
  PUT  /sources/mac/reader     where the myData app's reader helper is (sent by the myData app)
  /mcp                         MCP (Streamable HTTP) over the same registry and gate

Every route declares the scope it needs (`needs`, below; the scopes are in auth.SCOPES), and an app token
reaches only the routes its app's scopes allow. Agent tokens can use only /mcp (security.GuardMiddleware).
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import threading
import time
from contextlib import asynccontextmanager
from datetime import date, datetime, time as dtime, timedelta
from typing import Any, Callable, Literal

import psutil

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response, StreamingResponse
from fastapi.encoders import jsonable_encoder
from fastapi.routing import APIRoute
from pydantic import BaseModel, Field, SecretStr
from starlette.routing import Route

from .. import __version__
from ..tools import ApprovalError, Registry
from .appearance import DEFAULT_THEME, THEME_IDS, THEMES
from .assistant import Assistant
from .auth import SCOPES, Authenticator
from ..sources._db import MigrationError
from .backup import BackupError, BackupService, kept_until
from .logs import LAST_ERROR, log
from .state import HostState
from .mcp import build_mcp
from .model import ModelManager
from .security import GuardMiddleware
from .sync import SyncService
from .version import code_changed

_LOGGER = logging.getLogger("mydata.api")

# ---------------------------------------------------------------- scopes


class Needs:
    """A route's scope, checked before the route runs (and before its body is validated). Any one of the
    scopes given is enough."""

    def __init__(self, *scopes: str):
        unknown = set(scopes) - set(SCOPES)
        if not scopes or unknown:
            raise ValueError(f"unknown scope(s): {sorted(unknown)}")
        self.scopes = scopes

    def __call__(self, request: Request) -> None:
        principal = request.state.principal
        if any(principal.allows(s) for s in self.scopes):
            return
        if self.scopes == ("shutdown",):
            raise HTTPException(403, "only the myData app can stop the host")
        raise HTTPException(403, f"the {principal.name} app cannot use this (it needs the "
                                 f"{' or '.join(self.scopes)} scope)")


def needs(*scopes: str) -> list:
    """`dependencies=needs("approve")` on a route: the scope an app token needs to use it."""
    return [Depends(Needs(*scopes))]


def route_scopes(route) -> tuple[str, ...] | None:
    """The scopes a FastAPI route declared with `needs`, or None (and a route declaring two is refused)."""
    found = [d.dependency for d in getattr(route, "dependencies", []) if isinstance(d.dependency, Needs)]
    if len(found) > 1:
        raise RuntimeError(f"{route.path} declares more than one scope")
    return found[0].scopes if found else None


# ---------------------------------------------------------------- schemas


class Progress(BaseModel):
    status: str
    completed: int
    total: int
    percent: float


class ModelOut(BaseModel):
    name: str
    state: Literal["starting", "ollama_starting", "ollama_missing", "pulling", "loading", "ready", "error",
                   "disabled"]
    loaded: bool
    progress: Progress | None = None
    error: str | None = None
    ollama_reachable: bool
    ollama_started_by_host: bool


class MemoryOut(BaseModel):
    host_bytes: int = Field(description="memory the host process uses")
    model_bytes: int | None = Field(default=None, description="memory the loaded model uses in Ollama")


class ErrorOut(BaseModel):
    at: str
    message: str
    logger: str


class BackupOut(BaseModel):
    last_snapshot_at: str | None = Field(default=None, description="when the newest snapshot of the databases "
                                                                    "was taken (UTC); none yet: null")
    last_verified_at: str | None = Field(default=None, description="when a snapshot was last restored into a "
                                                                   "temporary folder and checked "
                                                                   "(`mydata backup verify`)")
    last_verify_ok: bool | None = Field(default=None, description="whether that restore drill passed")
    filevault: Literal["on", "off", "unknown"] = Field(description="whether the disk is encrypted (macOS "
                                                                   "FileVault); unknown on other systems")
    error: str | None = Field(default=None, description="why the last hourly snapshot failed; null once one "
                                                        "succeeds")


class StatusOut(BaseModel):
    version: str
    api_version: str = Field(description="a hash of this host's API (its routes and schemas); an app built "
                                         "against another API version replaces the host")
    stale: bool = Field(default=False, description="true when the host's code on disk changed since it started; "
                                                   "an app replaces it when the code on disk is the API it was "
                                                   "built against")
    ready: bool = Field(description="true when the assistant can answer")
    assistant_enabled: bool = Field(description="false when the user switched the assistant off")
    memory: MemoryOut
    last_error: ErrorOut | None = None
    uptime_seconds: float
    model: ModelOut
    agents_connected: int = Field(description="agent tokens used in the last five minutes")
    today: str = Field(description="the date the host treats as today")
    demo_date: bool = Field(description="true while today is pinned to the demo data's date")
    theme: str = Field(description="the theme every app uses; mode is per device and not stored here")
    mode: Literal["demo", "real"] = Field(description="real when a source is on (an account is linked, or This "
                                                      "Mac is turned on) or the host owns data (an address book "
                                                      "or calendar of its own): the tools serve that data, with "
                                                      "the real date; demo otherwise: the tools serve fake data "
                                                      "and the date is pinned")
    mac_available: bool = Field(default=False, description="true on a Mac host: the This Mac source exists")
    conversation_epoch: int = Field(ge=0, description="moves on by one at every switch between demo and real "
                                                      "mode, which ends every conversation: an app that sees it "
                                                      "change starts a new conversation and says why")
    backup: BackupOut | None = Field(default=None, description="snapshots of the databases and the last "
                                                               "restore drill")


class MessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    conversation_id: str | None = Field(default=None, description="omit to start a new conversation")


class ApprovalOut(BaseModel):
    id: str
    tool: str
    args: dict[str, Any] = Field(description="exactly what will run if approved")
    summary: str
    caller: str
    created_at: str
    status: Literal["pending", "approved", "rejected", "failed"]
    decided_at: str | None = None
    decided_by: str | None = Field(default=None, description="which app decided, e.g. app:myassistant")
    result: Any = None
    error: str | None = None
    context: dict[str, Any] = {}


class AssistantSettingsIn(BaseModel):
    enabled: bool


class ThemeOut(BaseModel):
    id: str
    name: str


class AppearanceOut(BaseModel):
    theme: str = Field(description="the theme every app uses; mode is per device and not stored here")
    themes: list[ThemeOut] = Field(description="every theme, in the order to show them")
    chosen: bool = Field(description="false until someone has chosen a theme; first run offers the choice")


class AppearanceIn(BaseModel):
    theme: str = Field(description="a theme id from GET /appearance")


class DecisionIn(BaseModel):
    decision: Literal["approve", "reject"]


class AgentOut(BaseModel):
    id: str
    name: str
    created_at: str
    revoked: bool
    revoked_at: str | None = None
    last_seen_at: str | None = None
    connected: bool


class AgentIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)


class AgentCreated(AgentOut):
    token: str = Field(description="shown once; give it to the agent as its bearer token for /mcp")


class ToolOut(BaseModel):
    name: str
    description: str
    input_schema: dict[str, Any]
    permission: Literal["read", "reversible", "irreversible"]


# ---------------------------------------------------------------- sources: accounts, sync, contacts, calendars


class AccountIn(BaseModel):
    provider: Literal["icloud"]
    email: str = Field(min_length=3, max_length=254,
                       description="the email of the Apple Account (the sign-in email, which may differ from an "
                                   "address on the user's own domain)")
    password: SecretStr = Field(min_length=1, max_length=256,
                                description="an app-specific password. Verified with the provider, then kept only "
                                            "in the Keychain; never returned, logged or written to a file")


class AccountOut(BaseModel):
    id: str
    provider: str
    email: str
    created_at: str
    label: str


class SyncCounts(BaseModel):
    address_books: int = 0
    contacts: int = 0
    calendars: int = 0
    events: int = 0


class AccountSyncOut(BaseModel):
    account_id: str
    state: Literal["idle", "syncing", "error"]
    last_success: str | None = None
    last_error: str | None = Field(default=None, description="a short message for the user; never a secret")
    last_attempt: str | None = None
    next_attempt: str | None = None
    counts: SyncCounts


class SyncOut(BaseModel):
    mode: Literal["demo", "real"]
    accounts: list[AccountSyncOut]


class LabeledValue(BaseModel):
    value: str
    label: str = ""


class PostalAddress(BaseModel):
    label: str = ""
    street: str = ""
    locality: str = ""
    region: str = ""
    postal_code: str = ""
    country: str = ""


class ContactOut(BaseModel):
    id: str
    account_id: str
    address_book_id: str
    display_name: str = Field(description="the name to show: never empty (organisation, email or phone when "
                                          "the card has no name)")
    full_name: str = ""
    given_name: str = ""
    family_name: str = ""
    nickname: str = ""
    organisation: str = ""
    emails: list[LabeledValue] = []
    phones: list[LabeledValue] = []
    addresses: list[PostalAddress] = []
    birthday: str | None = None
    note: str = ""
    has_photo: bool = False
    # Required, not defaulted: OpenAPI Generator's Dart output cannot compile a defaulted enum.
    source: Literal["mac", "icloud", "mydata"] = Field(description="where the contact comes from: mydata for a "
                                                                   "contact the host owns (made in an app; the only "
                                                                   "copy is on this host)")
    notes_included: bool = Field(default=True, description="false when the source never reads notes (This Mac): "
                                                           "show no Notes field")
    etag: str = Field(description="the contact's current version, to send back as If-Match when changing it; it "
                                  "changes with every change, a delete or restore included")
    editable: bool = Field(description="true for a contact the host owns, which the apps may change and delete; "
                                       "false for one followed from a source (change it there)")
    on_phone: bool | None = Field(default=None, description="false for a contact the host owns: it is on myData "
                                                            "only, not on any phone yet. Null for a followed one "
                                                            "(the source decides where it is)")
    purge_after: str | None = Field(default=None, description="for a contact in Recently deleted: when it is "
                                                              "deleted for good (UTC)")
    changed_in_source: str | None = Field(default=None, description="for a contact the host owns that was imported "
                                                                    "from a followed account: that account's id "
                                                                    "(GET /sources) when its copy changed since the "
                                                                    "import (\"changed in <source> since import\", "
                                                                    "to review); null otherwise")
    sort_letter: str = Field(description="the contact list's letter group: the first letter of display_name "
                                         "without accents, upper case; \"#\" when it does not start with a letter "
                                         "(digits, symbols, Chinese, Japanese kanji or Korean characters)")
    caption: str | None = Field(default=None, description="the line under the name in the contact list: the "
                                                          "organisation, else the first email or phone that is not "
                                                          "already the name; none when there is nothing else to say")
    created_at: str
    modified_at: str
    deleted_at: str | None = None


class ContactField(BaseModel):
    label: str = Field(default="", description="the source's label in sentence case (\"Mobile\", \"Home fax\"), "
                                               "or a label the user typed, exactly as written; empty when none")
    value: str = Field(description="as the source wrote it. Birthday: YYYY-MM-DD, or --MM-DD when the year is not "
                                   "known. Address: plain lines (street, then locality, region and postal code, "
                                   "then country); `address` has the parts")
    address: PostalAddress | None = Field(default=None, description="an address's parts, to lay it out in the "
                                                                    "locale's order; only for kind address")


class ContactFieldGroup(BaseModel):
    # Required, not defaulted: OpenAPI Generator's Dart output cannot compile a defaulted enum.
    kind: Literal["phone", "email", "address", "birthday", "url", "note"]
    title: str = Field(description="the group's heading: Phone, Email, Address, Birthday, Links or Notes")
    items: list[ContactField]


class ContactDetailOut(ContactOut):
    source_label: str = Field(description="the source inside a sentence: \"this Mac\", \"the iCloud account "
                                          "<email>\" (\"From this Mac. Change it in Contacts.\") or \"myData\" "
                                          "for a contact the host owns")
    job_title: str = ""
    middle_name: str = Field(default="", description="for the edit form, as are the four fields below")
    name_prefix: str = ""
    name_suffix: str = ""
    company: str = Field(default="", description="the organisation's name alone (organisation also has the "
                                                 "department, after a comma)")
    department: str = ""
    urls: list[LabeledValue] = Field(default=[], description="web addresses as the source wrote them; never "
                                                            "trusted to say what they open")
    fields: list[ContactFieldGroup] = Field(description="the contact's values for its page, grouped by kind in this "
                                                        "order: phone, email, address, birthday, url, note. A kind "
                                                        "with no values is left out; note only when the source reads "
                                                        "notes and the note is not empty (never for This Mac)")
    raw_vcard: str | None = Field(default=None, description="the card as the server sent it; only with ?raw=1")
    changed_in_source_label: str | None = Field(default=None, description="with changed_in_source: that source "
                                                                          "inside a sentence (\"the iCloud account "
                                                                          "you@example.com\")")


class LabeledValueIn(BaseModel):
    label: str | None = Field(default=None, max_length=1000, description="mobile, iphone, home, work, main, fax, "
                                                                         "pager, other, school, homepage, homefax, "
                                                                         "workfax or otherfax (any case, or as the "
                                                                         "apps show them: \"Home fax\"), or any "
                                                                         "text, kept as typed")
    value: str | None = Field(default=None, max_length=20000, description="an empty value is left out")


class PostalAddressIn(BaseModel):
    label: str | None = Field(default=None, max_length=1000)
    street: str | None = Field(default=None, max_length=20000, description="may hold line breaks")
    locality: str | None = Field(default=None, max_length=20000, description="the city or town")
    region: str | None = Field(default=None, max_length=20000)
    postal_code: str | None = Field(default=None, max_length=20000)
    country: str | None = Field(default=None, max_length=20000)


class ContactIn(BaseModel):
    """A contact's editable fields. Creating: every field is optional, but a name, company, nickname, email or
    phone is needed. Changing (PATCH): a field left out keeps its value; null, "" or [] clears it; a list
    replaces the contact's list (values whose label and text are unchanged are kept as they are). Only the
    card's lines whose values change are written."""
    given_name: str | None = Field(default=None, max_length=20000)
    family_name: str | None = Field(default=None, max_length=20000)
    middle_name: str | None = Field(default=None, max_length=20000)
    name_prefix: str | None = Field(default=None, max_length=20000)
    name_suffix: str | None = Field(default=None, max_length=20000)
    nickname: str | None = Field(default=None, max_length=20000)
    company: str | None = Field(default=None, max_length=20000)
    department: str | None = Field(default=None, max_length=20000)
    job_title: str | None = Field(default=None, max_length=20000)
    birthday: str | None = Field(default=None, max_length=100, description="YYYY-MM-DD, or --MM-DD when the year is "
                                                                          "not known")
    note: str | None = Field(default=None, max_length=40000, description="may hold line breaks")
    phones: list[LabeledValueIn] | None = Field(default=None, max_length=1000)
    emails: list[LabeledValueIn] | None = Field(default=None, max_length=1000)
    urls: list[LabeledValueIn] | None = Field(default=None, max_length=1000)
    addresses: list[PostalAddressIn] | None = Field(default=None, max_length=1000)


class FieldErrorsOut(BaseModel):
    detail: str
    fields: dict[str, str] = Field(description="one message per field that is not valid, by its path in the body "
                                               "(\"emails[1].value\"); never the value itself")


class PreconditionFailedOut(BaseModel):
    detail: str
    etag: str = Field(description="the contact's current etag")


class ContactWriteOut(BaseModel):
    contact: ContactDetailOut = Field(description="the contact as it is now (deleted_at set after a delete)")
    undo_id: str | None = Field(default=None, description="POST /undo/{undo_id} undoes this change; null when "
                                                          "nothing changed")


class UndoOut(BaseModel):
    undo_id: str
    contact: ContactDetailOut = Field(description="the contact as it is after the undo (for a merge: the first "
                                                  "original, restored)")
    contact_ids: list[str] = Field(default=[], description="every contact the undo changed: for a merge, each "
                                                           "original (restored) and the merged contact (moved to "
                                                           "Recently deleted)")


class MergeContactIn(BaseModel):
    id: str = Field(min_length=1, max_length=100)
    etag: str = Field(min_length=1, max_length=200, description="the contact's etag as the user saw it")


class MergeIn(BaseModel):
    contacts: list[MergeContactIn] = Field(min_length=2, max_length=20, description="the owned contacts to merge, in "
                                                                                   "order")
    names_from: str | None = Field(default=None, max_length=100, description="the contact whose names (and lines) "
                                                                             "the merged one starts from; default "
                                                                             "the first")


class MergeOut(BaseModel):
    contact: ContactDetailOut = Field(description="the merged contact")
    undo_id: str = Field(description="POST /undo/{undo_id} undoes the merge while nothing changed since")
    merged: list[str] = Field(description="the originals' ids, now in Recently deleted")


class ImportCountsOut(BaseModel):
    cards: int = Field(description="cards in the input, read or not")
    contacts: int = Field(description="cards that are contacts (people and organisations)")
    groups: int = Field(description="group cards: imported as groups, never listed as contacts")
    skipped: int = Field(description="cards that could not be read (the loss report says why)")
    new: int
    duplicates: int = Field(description="cards whose email or phone an owned contact of the same name already has")
    in_file: int = Field(description="cards repeated in the input")
    unchanged: int = Field(description="cards imported before, unchanged")
    updates: int = Field(description="cards imported before that changed, the owned copy unedited since")
    conflicts: int = Field(description="cards imported before that changed, the owned copy edited (or merged) since: "
                                       "not written")
    deleted: int = Field(description="cards imported before whose owned copy is in Recently deleted")
    suggestions: int = Field(description="cards with a contact of the same name only (a suggestion)")
    followed_matches: int = Field(description="cards whose email or phone a followed contact has")
    missing: int = Field(description="contacts earlier imports from this source brought in that the input no longer "
                                     "has (reported, never deleted)")
    to_import: int
    to_update: int
    to_link: int
    created: int | None = Field(default=None, description="after the commit: contacts created")
    groups_created: int | None = None
    updated: int | None = None
    linked: int | None = None
    not_written: int | None = None


class ImportNoteOut(BaseModel):
    code: str = Field(description="skipped_unreadable, skipped_no_end, skipped_version, skipped_empty, "
                                  "skipped_too_large, skipped_too_many, guessed_charset, outside_text, "
                                  "unreadable_entry, nested_zip, encrypted, unsupported_compression (losses); "
                                  "converted_21, declared_charset, other_files (changes)")
    count: int
    message: str = Field(description="for the user; holds no contact data")
    entries: list[str] = Field(default=[], description="unreadable_entry: the names of the files in the zip not read")


class ImportMatchOut(BaseModel):
    display_name: str
    source: str = Field(description="mydata (owned), icloud, mac, or file (an earlier card in the same input)")
    strength: str = Field(description="same_origin (imported from this card before), strong (same email or phone, "
                                      "and the same name or none), suggestion (the same name only, or an email or "
                                      "phone shared under another name: never acted on)")
    signals: list[str] = Field(description="origin, uid, identical, email, phone, name")
    contact_id: str | None = None
    account_id: str | None = None
    item_index: int | None = Field(default=None, description="for source file: the earlier card's index")


class ImportItemOut(BaseModel):
    index: int = Field(description="the card's position in the input, from 0")
    kind: str | None = Field(default=None, description="individual, org or group; null for a card not read")
    display_name: str
    status: str = Field(description="new, duplicate, in_file, unchanged, update, conflict, deleted, skipped")
    reason: str | None = Field(default=None, description="conflict: edited, merged or kept_yours; skipped: "
                                                         "unreadable, no_end, version, empty, too_large (cards past "
                                                         "the first 50000 are counted only, with no item)")
    action: str = Field(description="what the commit does unless chosen otherwise: import, update, link (keep the "
                                    "matching contact of yours and hide the followed copy) or skip")
    choices: list[str] = Field(description="the actions this card may be given")
    converted_from: str | None = Field(default=None, description="2.1 for a vCard 2.1 stored as 3.0")
    entry: str | None = Field(default=None, description="the zip entry the card came from (a name only)")
    matches: list[ImportMatchOut] = []


class ImportMissingOut(BaseModel):
    contact_id: str
    display_name: str


class StopFollowingOut(BaseModel):
    account_id: str
    label: str = Field(description="the source as a heading")
    contacts_followed: int = Field(description="its contacts with no copy on myData (skipped, not imported yet): "
                                               "stopping following removes them from myData")
    contacts_linked: int = Field(default=0, description="its contacts hidden behind a contact of yours kept instead "
                                                        "(link), which may hold details yours does not")
    contacts_changed: int = Field(default=0, description="its contacts changed since they were imported (the "
                                                         "copy on myData is older)")
    calendars_followed: int = Field(description="stopping following the account stops following these too; they "
                                                "are not imported yet")
    message: str


class ImportPreviewOut(BaseModel):
    id: str = Field(description="the preview's id, held by the host until expires_at (not across a restart)")
    expires_at: str
    source: str = Field(description="file, or icloud for a copy of a followed iCloud account")
    label: str = Field(description="the file's name, or the source as a heading")
    account_id: str | None = None
    counts: ImportCountsOut
    losses: list[ImportNoteOut] = Field(description="what in the input will not reach the host; when not empty, "
                                                    "commit needs accept_losses")
    changes: list[ImportNoteOut] = Field(description="what is stored differently without being lost")
    needs_acceptance: bool
    missing: list[ImportMissingOut]
    items: list[ImportItemOut]
    stop_following: StopFollowingOut | None = Field(default=None, description="for a copy of a followed account: "
                                                                              "the app may offer to stop following it")


class ImportChoiceIn(BaseModel):
    index: int = Field(ge=0)
    action: Literal["import", "update", "link", "skip"]


class ImportCommitIn(BaseModel):
    address_book_id: str | None = Field(default=None, max_length=100, description="an owned address book; default "
                                                                                  "the host's \"myData\" one "
                                                                                  "(made if missing)")
    choices: list[ImportChoiceIn] = Field(default=[], max_length=50000, description="actions other than each card's "
                                                                                    "default")
    accept_losses: bool = Field(default=False, description="needed when the preview has losses")


class ImportConflictOut(BaseModel):
    index: int
    contact_id: str | None = None
    display_name: str
    reason: str | None = None


class ImportOut(BaseModel):
    id: str
    source: str
    label: str
    source_account: str | None = None
    started_at: str
    finished_at: str | None = None
    status: str = Field(description="committed or undone")
    counts: dict[str, Any] = Field(description="as ImportCountsOut, plus undo (removed, reverted, unlinked, kept, "
                                               "gone) once undone")
    address_book_id: str | None = None
    undone_at: str | None = None


class ImportCommittedOut(ImportOut):
    conflicts: list[ImportConflictOut] = []
    missing: list[ImportMissingOut] = []
    stop_following: StopFollowingOut | None = None


class ImportUndoneOut(BaseModel):
    summary: ImportOut = Field(description="the import as it is now (status undone)")
    removed: int = Field(description="contacts it created, now in Recently deleted")
    groups_removed: int = Field(default=0, description="group cards it created, now in Recently deleted with them")
    reverted: int = Field(description="contacts it updated, back to their earlier text")
    unlinked: int
    kept: list[ImportMissingOut] = Field(description="contacts changed since the import: left as they are")
    gone: int = Field(description="contacts already in Recently deleted or deleted for good")


class TrashItemOut(BaseModel):
    id: str
    # Required, not defaulted: OpenAPI Generator's Dart output cannot compile a defaulted enum.
    kind: Literal["contact"] = Field(description="what the item is (events come later)")
    title: str = Field(description="the item's name as the apps show it")
    deleted_at: str
    purge_after: str = Field(description="when it is deleted for good (UTC)")
    backups_kept_until: str = Field(description="YYYY-MM-DD: copies of it in the host's snapshots are kept until "
                                                "this day if it is deleted for good now, while the host keeps "
                                                "running (the apps say so before deleting it for good)")
    contact: ContactOut | None = Field(default=None, description="for kind contact")


class CalendarOut(BaseModel):
    id: str
    account_id: str
    name: str
    color: str | None = Field(default=None, description="#RRGGBB as the source gives it (any alpha dropped); none "
                                                        "when the calendar has no colour")
    # Required, not defaulted: OpenAPI Generator's Dart output cannot compile a defaulted enum.
    source: Literal["mac", "icloud"] = Field(description="the source the calendar is read through")
    source_label: str = Field(description="the source as the calendar list heads its group: \"This Mac\" or "
                                          "\"iCloud account <email>\"")
    account_caption: str | None = Field(default=None, description="This Mac only: the account the calendar belongs "
                                                                  "to on the Mac, as macOS names it (\"iCloud\", "
                                                                  "\"Google\", \"Exchange\"), or \"Only on this "
                                                                  "Mac\", \"Birthdays from Contacts\", \"Subscribed\"."
                                                                  " None for an iCloud account's calendars, and when "
                                                                  "the Mac names no account")


class EventOut(BaseModel):
    event_id: str
    calendar_id: str
    uid: str
    recurrence_id: str | None = None
    title: str
    location: str = ""
    notes: str = ""
    start: str = Field(description="ISO date-time in the host's time zone, or YYYY-MM-DD for an all-day event")
    end: str = Field(description="as start; an all-day event's end is the day after its last day (exclusive)")
    all_day: bool
    time_zone: str | None = Field(default=None, description="the event's own zone; none for all-day events")
    source: Literal["mac", "icloud"] = Field(description="where the event comes from")


class CoverageOut(BaseModel):
    source: Literal["mac", "icloud"]
    account_id: str
    covered_start: str | None = Field(default=None, description="first day the source holds; none: no limit")
    covered_end: str | None = Field(default=None, description="last day the source holds (included); none: no "
                                                              "limit")
    complete: bool = Field(description="true when the source holds every day asked for")
    reason: Literal["no_access", "not_read_yet"] | None = Field(
        default=None, description="when the source holds no days at all: why")


class EventsOut(BaseModel):
    events: list[EventOut]
    coverage: list[CoverageOut] = Field(description="per source holding calendars, which days it holds. When a "
                                                    "source is not complete, events on days outside its range are "
                                                    "not known: do not show those days as empty")


class WindowOut(BaseModel):
    start: str
    end: str


class MacContainerOut(BaseModel):
    id: str
    name: str
    kind: str = Field(description="cardDAV, exchange, local or unassigned")
    included: bool


class MacCalendarOut(BaseModel):
    id: str
    name: str
    source_name: str = ""
    color: str | None = None
    included: bool


class SourceOut(BaseModel):
    id: str = Field(description="\"mac\" for This Mac; the account id for an iCloud account")
    kind: Literal["mac", "icloud"]
    available: bool = True
    enabled: bool
    decided: bool | None = Field(default=None, description="This Mac: true once the user turned it on or off "
                                                           "(the myData app's first-run step is then not shown)")
    email: str | None = Field(default=None, description="iCloud: the account's email")
    contacts_status: str | None = Field(default=None, description="This Mac: notDetermined, restricted, denied, "
                                                                  "authorized, or unknown (not reported yet, or a "
                                                                  "value this host does not know: not readable)")
    calendars_status: str | None = Field(default=None, description="This Mac: notDetermined, restricted, denied, "
                                                                   "fullAccess, writeOnly, or unknown (as "
                                                                   "contacts_status)")
    contact_containers: list[MacContainerOut] = []
    calendars: list[MacCalendarOut] = []
    all_contact_containers: bool | None = Field(
        default=None, description="This Mac: true when no choice was made (every account, including ones added "
                                  "later); send contact_containers null to keep it so")
    all_calendars: bool | None = Field(default=None, description="This Mac: as all_contact_containers, for calendars")
    notes_included: bool = Field(description="false for This Mac: contact notes are never read")
    window: WindowOut | None = Field(default=None, description="This Mac: the days of events it holds")
    reader_running: bool | None = Field(default=None, description="This Mac: the reader helper is connected")
    state: Literal["idle", "syncing", "error"] | None = None
    last_update: str | None = None
    last_error: str | None = Field(default=None, description="a short message for the user; never a secret")
    counts: SyncCounts | None = Field(default=None, description="what the source holds now: for an iCloud account, "
                                                                 "as of its last sync; for This Mac while it is on")


class SourcesOut(BaseModel):
    sources: list[SourceOut]


class MacSourceIn(BaseModel):
    """Send all three fields (the generated client does): a field left out keeps its value, but null means
    everything. To keep a choice, send it back as GET /sources shows it: null when all_contact_containers
    (all_calendars) is true, else the ids marked included."""
    enabled: bool | None = Field(default=None, description="null keeps it; false deletes everything This Mac "
                                                           "mirrored (snapshots keep copies until they expire) and "
                                                           "stops its reader")
    contact_containers: list[str] | None = Field(default=None, description="container ids to include; null = all, "
                                                                           "including accounts added later")
    calendars: list[str] | None = Field(default=None, description="calendar ids to include; null = all, including "
                                                                  "calendars added later")


class AccessIn(BaseModel):
    what: Literal["contacts", "calendars"]


class ReaderIn(BaseModel):
    path: str = Field(min_length=1, max_length=4096,
                      description="absolute path of myData.app/Contents/Helpers/myDataReader.app")


MAX_EVENT_DAYS = 400


SSE_DESCRIPTION = """Server-sent events, one JSON object per `data:` line, `event:` naming the type:
`reset` {mode, epoch}, `conversation` {conversation_id}, `progress` {tool, label}, `result` {tool, kind, header, items,
mode}, `delta` {text}, `step` {}, `pending_approval` {approval}, `clarify` {options, text}, `message` {text, outcome,
by}, `error` {message}, `done` {}. A `result` is a tool's result, sent the moment the tool returns, with a header
written by code; kind is events, mail, contacts, photos or event_created. Its mode is "real" when the items are
the user's own data and "demo" for sample data; a contact item carries its id (as in GET /contacts) and an event
item its day, `date` (YYYY-MM-DD), so a real item can be opened in myContacts or myCalendar. `delta` text is provisional: on `step` discard
what has streamed so far; `message.text` is the reply, and `message.by` is "code" when the shown result was the
answer (its text is then the result's header) or "model" for a sentence the model wrote. `reset` comes first when
the named conversation was ended by a switch between demo and real mode (`epoch` is GET /status's
conversation_epoch): the message starts a new conversation, whose id the `conversation` event that follows
gives."""


# ---------------------------------------------------------------- app


def create_app(auth: Authenticator, registry: Registry, models: ModelManager, assistant: Assistant,
               state: HostState | None = None, shutdown: Callable[[], None] | None = None,
               sources: SyncService | None = None, backups: BackupService | None = None):
    """The ASGI app: FastAPI routes plus /mcp, wrapped in the token and Host checks. Without `sources`
    (the OpenAPI document, older tests) the account and mirror routes answer 503; without `backups`,
    /status has no backup section."""
    started = time.time()
    session_manager = build_mcp(registry)
    # Without a state file (the OpenAPI document), the theme lives in memory only.
    no_state = {"theme": DEFAULT_THEME, "chosen": False}

    def current_theme() -> str:
        return state.theme if state is not None else no_state["theme"]

    def current_mode() -> str:
        return "real" if registry.mode == "real" else "demo"

    def need_sources() -> SyncService:
        if sources is None:
            raise HTTPException(503, "accounts are not available in this host")
        return sources

    @asynccontextmanager
    async def lifespan(_app):
        async with session_manager.run():
            yield

    # No /openapi.json route: the document is written by `mydata openapi` (openapi.py), never served.
    app = FastAPI(title="myData host", version=__version__, lifespan=lifespan, docs_url=None, redoc_url=None,
                  openapi_url=None,
                  # operation ids = function names, so the generated client reads status(), decide(), ...
                  generate_unique_id_function=lambda route: route.name,
                  description="Local API of the myData host. Listens on localhost only; every request needs "
                              "`Authorization: Bearer <token>` from the token file in the host's folder.")

    @app.get("/status", dependencies=needs("status"), tags=["host"], response_model=StatusOut)
    def status() -> StatusOut:
        from .openapi import api_version  # here, not at the top: openapi.py builds the app from this module
        m = models.status()
        return StatusOut(version=__version__, api_version=api_version(), stale=code_changed(),
                         ready=m.state == "ready", assistant_enabled=models.enabled,
                         memory=MemoryOut(host_bytes=psutil.Process(os.getpid()).memory_info().rss,
                                          model_bytes=models.model_bytes() if m.state == "ready" else None),
                         last_error=ErrorOut(**LAST_ERROR.last) if LAST_ERROR.last else None,
                         uptime_seconds=round(time.time() - started, 1),
                         model=ModelOut(**m.to_json()),
                         agents_connected=sum(a["connected"] for a in auth.agents.list()),
                         today=assistant.today().isoformat(),
                         demo_date=registry.mode == "demo" and assistant.settings.pin_today is not None,
                         theme=current_theme(), mode=current_mode(),
                         conversation_epoch=assistant.conversation_epoch,
                         mac_available=sources is not None and sources.mac_available,
                         backup=BackupOut(**backups.status()) if backups is not None else None)

    @app.post("/model/retry", dependencies=needs("assistant", "admin"), tags=["host"], response_model=StatusOut)
    def retry() -> StatusOut:
        """Try again to get the model ready (after an error, or once Ollama is installed)."""
        models.retry()
        return status()

    @app.post("/assistant/messages", dependencies=needs("assistant"), tags=["assistant"],
              response_class=StreamingResponse,
              responses={200: {"content": {"text/event-stream": {"schema": {"type": "string"}}},
                               "description": SSE_DESCRIPTION},
                         503: {"description": "the model is not ready yet; see GET /status"}})
    async def messages(body: MessageIn):
        if not models.enabled:
            raise HTTPException(503, "the assistant is switched off; switch it on in the myData app")
        if not models.ready():
            raise HTTPException(503, "the model is not ready yet; see GET /status")
        return StreamingResponse(_sse(assistant, body.text, body.conversation_id), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

    @app.put("/assistant/settings", dependencies=needs("admin"), tags=["assistant"], response_model=StatusOut)
    def assistant_settings(body: AssistantSettingsIn) -> StatusOut:
        """Switch the assistant on (the model is prepared, downloading it if needed) or off (nothing is
        downloaded or loaded; the rest of myData works without it)."""
        if state is not None:
            state.set_assistant_enabled(body.enabled)
        models.set_enabled(body.enabled)
        return status()

    def appearance_out() -> AppearanceOut:
        chosen = state.theme_chosen if state is not None else no_state["chosen"]
        return AppearanceOut(theme=current_theme(), themes=[ThemeOut(id=i, name=n) for i, n in THEMES],
                             chosen=chosen)

    @app.get("/appearance", dependencies=needs("status"), tags=["appearance"], response_model=AppearanceOut)
    def appearance() -> AppearanceOut:
        """The theme every app uses, and the themes to choose from. Light or dark mode is per device."""
        return appearance_out()

    @app.put("/appearance", dependencies=needs("admin"), tags=["appearance"], response_model=AppearanceOut,
             responses={400: {"description": "no such theme"}})
    def set_appearance(body: AppearanceIn) -> AppearanceOut:
        """Set the theme every app uses. Apps follow the change through GET /status."""
        if body.theme not in THEME_IDS:
            raise HTTPException(400, f"no such theme: {body.theme}; choose one of {', '.join(THEME_IDS)}")
        if state is not None:
            state.set_theme(body.theme)
        else:
            no_state["theme"] = body.theme
            no_state["chosen"] = True
        return appearance_out()

    @app.post("/shutdown", dependencies=needs("shutdown"), tags=["host"], status_code=202,
              responses={403: {"description": "only the myData app can stop the host"}})
    def shutdown_host() -> dict:
        """Stop the host. Only the myData app (which owns the host's lifetime) and the mydata command may."""
        if shutdown is not None:
            threading.Timer(0.2, shutdown).start()  # after this response is sent
        return {"stopping": True}

    @app.get("/approvals", dependencies=needs("approve"), tags=["approvals"], response_model=list[ApprovalOut])
    def approvals(status: Literal["pending", "approved", "rejected", "failed"] | None = None) -> list[ApprovalOut]:
        return [ApprovalOut(**a.to_json()) for a in registry.approvals(status)]

    @app.get("/approvals/{approval_id}", dependencies=needs("approve"),
             tags=["approvals"], response_model=ApprovalOut, responses={404: {"description": "no such approval"}})
    def approval(approval_id: str) -> ApprovalOut:
        a = registry.approval(approval_id)
        if a is None:
            raise HTTPException(404, "no such approval")
        return ApprovalOut(**a.to_json())

    @app.post("/approvals/{approval_id}", dependencies=needs("approve"), tags=["approvals"],
              response_model=ApprovalOut,
              responses={404: {"description": "no such approval"}, 409: {"description": "already decided"}})
    def decide(approval_id: str, body: DecisionIn, request: Request) -> ApprovalOut:
        try:
            a = registry.decide(approval_id, body.decision == "approve", decided_by=request.state.principal.label)
        except ApprovalError as e:
            code = 404 if "no such" in str(e) else 409
            raise HTTPException(code, str(e)) from None
        assistant.note_decision(a)
        return ApprovalOut(**a.to_json())

    @app.get("/tools", dependencies=needs("admin"), tags=["tools"], response_model=list[ToolOut])
    def tools() -> list[ToolOut]:
        return [ToolOut(**t) for t in registry.describe()]

    @app.get("/agents", dependencies=needs("admin"), tags=["agents"], response_model=list[AgentOut])
    def agents() -> list[AgentOut]:
        return [AgentOut(**a) for a in auth.agents.list()]

    @app.post("/agents", dependencies=needs("admin"), tags=["agents"], response_model=AgentCreated, status_code=201)
    def create_agent(body: AgentIn) -> AgentCreated:
        try:
            agent, token = auth.agents.create(body.name)
        except ValueError as e:
            raise HTTPException(422, str(e)) from None
        return AgentCreated(**agent.public(None), token=token)

    @app.delete("/agents/{agent_id}", dependencies=needs("admin"),
                tags=["agents"], response_model=AgentOut, responses={404: {"description": "no such agent"}})
    def revoke_agent(agent_id: str) -> AgentOut:
        try:
            agent = auth.agents.revoke(agent_id)
        except KeyError as e:
            raise HTTPException(404, str(e)) from None
        return AgentOut(**agent.public(None))

    @app.exception_handler(RequestValidationError)
    async def validation_error(_request: Request, exc: RequestValidationError) -> JSONResponse:
        """FastAPI's 422, without the submitted values: a rejected body can hold a password."""
        errors = [{k: v for k, v in e.items() if k != "input"} for e in exc.errors()]
        return JSONResponse(status_code=422, content={"detail": jsonable_encoder(errors)})

    async def store_unavailable(_request: Request, exc: Exception) -> JSONResponse:
        """A store that could not be opened (its migration refused or rolled back): 503 with the message,
        which names files and versions only, and is also in /status's last_error."""
        return JSONResponse(status_code=503, content={"detail": str(exc)})

    async def json_error(_request: Request, exc: _JSONError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=exc.content, headers=exc.headers)

    app.add_exception_handler(_JSONError, json_error)
    app.add_exception_handler(BackupError, store_unavailable)
    app.add_exception_handler(MigrationError, store_unavailable)

    _routes_sources(app, need_sources, current_mode)
    # A route without a scope would be open to every app token: refuse to start rather than serve one.
    missing = [r.path for r in app.routes if isinstance(r, APIRoute) and route_scopes(r) is None]
    if missing:
        raise RuntimeError(f"routes without a scope: {missing}")
    app.router.routes.append(Route("/mcp", endpoint=_mcp_endpoint(session_manager)))
    app.state.session_manager = session_manager
    return GuardMiddleware(app, auth)


def _routes_sources(app: FastAPI, need: Callable[[], SyncService], current_mode: Callable[[], str]) -> None:
    """Accounts, sync status and the mirrored contacts and calendars. App tokens only (the guard keeps agent
    tokens to /mcp)."""
    from ..sources.providers import VerificationError
    from ..sources.secrets import SecretStoreError
    unavailable = {503: {"description": "accounts are not available in this host"}}

    @app.get("/accounts", dependencies=needs("sources:read"),
             tags=["sources"], response_model=list[AccountOut], responses=unavailable)
    def accounts() -> list[AccountOut]:
        """Linked accounts. Passwords are never returned."""
        return [AccountOut(**a.public()) for a in need().accounts.list()]

    @app.post("/accounts", dependencies=needs("sources:manage"),
              tags=["sources"], response_model=AccountOut, status_code=201,
              responses={400: {"description": "the provider did not accept the details, or the account is "
                                              "already linked; the message says which"}, **unavailable})
    def add_account(body: AccountIn) -> AccountOut:
        """Link an account. The provider checks the email and password first (discovery); nothing is stored
        unless that succeeds. Then the host mirrors its contacts and calendars, read-only, and switches to
        real mode."""
        service = need()
        try:
            account = service.add_account(body.provider, body.email, body.password.get_secret_value())
        except (ValueError, VerificationError) as e:
            raise HTTPException(400, str(e)) from None
        except SecretStoreError as e:
            raise HTTPException(503, f"{e}. Nothing was stored.") from None
        return AccountOut(**account.public())

    @app.delete("/accounts/{account_id}", dependencies=needs("sources:manage"),
                tags=["sources"], response_model=AccountOut,
                responses={404: {"description": "no such account"}, **unavailable})
    def remove_account(account_id: str) -> AccountOut:
        """Unlink an account: its mirrored contacts and calendars and its Keychain item are deleted. Copies
        in the host's snapshots stay until they expire (within 12 months while the host runs). Nothing
        changes at the provider. With no account left the host returns to demo mode."""
        service = need()
        try:
            account = service.remove_account(account_id)
        except KeyError:
            raise HTTPException(404, "no such account") from None
        except SecretStoreError as e:
            raise HTTPException(503, str(e)) from None
        return AccountOut(**account.public())

    @app.post("/accounts/{account_id}/sync", dependencies=needs("sources:manage"),
              tags=["sources"], response_model=AccountSyncOut, status_code=202,
              responses={404: {"description": "no such account"}, **unavailable})
    def sync_account(account_id: str) -> AccountSyncOut:
        """Sync now: the account is synced next, in the background. Follow it with GET /sync."""
        try:
            return AccountSyncOut(**need().request_sync(account_id))
        except KeyError:
            raise HTTPException(404, "no such account") from None

    @app.get("/sync", dependencies=needs("sources:read"), tags=["sources"], response_model=SyncOut)
    def sync_status() -> SyncOut:
        """The mode, and each account's sync status."""
        return SyncOut(mode=current_mode(), accounts=[AccountSyncOut(**r) for r in _status_rows(need)])

    @app.get("/contacts", dependencies=needs("contacts:read"),
             tags=["sources"], response_model=list[ContactOut], responses=unavailable)
    def contacts(query: str | None = Query(default=None, max_length=200,
                                           description="search names, organisation, emails and phones"),
                 limit: int = Query(default=100, ge=1, le=1000), offset: int = Query(default=0, ge=0)
                 ) -> list[ContactOut]:
        """Mirrored contacts by name, or the ones matching `query` (every word, as a prefix)."""
        store = need().contacts
        if query and query.strip():
            rows = store.search(query, limit=limit + offset)[offset:]
        else:
            rows = store.list(limit=limit, offset=offset)
        return [ContactOut(**_list_view(r)) for r in rows]

    @app.get("/contacts/{contact_id}", dependencies=needs("contacts:read"),
             tags=["sources"], response_model=ContactDetailOut,
             responses={200: {"headers": {"ETag": {"description": "the contact's etag", "schema": {"type": "string"}}}},
                        404: {"description": "no such contact"}, **unavailable})
    def contact(contact_id: str, response: Response,
                raw: bool = Query(default=False, description="include the raw vCard")) -> ContactDetailOut:
        """One contact, for its page: the fields grouped by kind, the job title and where the card comes from;
        whether it can be changed here, and its etag (also the ETag header)."""
        service = need()
        row = service.contacts.get(contact_id)
        if row is None:
            raise HTTPException(404, "no such contact")
        out = _detail(service, row, raw=raw)
        response.headers["ETag"] = out.etag
        return out

    _routes_contact_writes(app, need, unavailable)
    _routes_imports(app, need, unavailable)

    @app.get("/calendars", dependencies=needs("calendar:read"),
             tags=["sources"], response_model=list[CalendarOut], responses=unavailable)
    def calendars() -> list[CalendarOut]:
        """Every mirrored calendar, grouped by source: This Mac first, then each iCloud account. The same
        calendar seen through This Mac and through an iCloud account is listed twice, once per source."""
        return [CalendarOut(**c) for c in need().calendar_list()]

    @app.get("/contacts/{contact_id}/photo", dependencies=needs("contacts:read"),
             tags=["sources"], response_class=Response,
             responses={200: {"content": {"image/jpeg": {"schema": {"type": "string", "format": "binary"}},
                                          "image/png": {"schema": {"type": "string", "format": "binary"}}},
                              "description": "the photo"},
                        404: {"description": "no such contact, or it has no photo (show initials)"}, **unavailable})
    def contact_photo(contact_id: str) -> Response:
        """The contact's photo, as JPEG or PNG. 404 when there is none: the app shows initials."""
        found = need().contacts.photo(contact_id)
        if found is None:
            raise HTTPException(404, "no photo")
        data, media_type = found
        return Response(content=data, media_type=media_type, headers={"Cache-Control": "private, max-age=60"})

    @app.get("/events", dependencies=needs("calendar:read"), tags=["sources"], response_model=EventsOut,
             responses={400: {"description": "end is before start, or the range is too long"}, **unavailable})
    def events(start: date = Query(description="first day, YYYY-MM-DD"),
               end: date = Query(description="last day, YYYY-MM-DD (included)"),
               calendar: list[str] | None = Query(default=None, description="calendar ids; repeat for several. "
                                                                             "Omit for every calendar")
               ) -> EventsOut:
        """Events overlapping the days from start to end (both included), in the host's time zone, with
        recurring events expanded into occurrences; and, per source, which of those days it holds. This
        Mac holds a window (one year back, two ahead): days outside it are unknown, not empty."""
        from ..sources.ical import local_timezone
        if end < start:
            raise HTTPException(400, "end is before start")
        if (end - start).days >= MAX_EVENT_DAYS:
            raise HTTPException(400, f"ask for at most {MAX_EVENT_DAYS} days at a time")
        service = need()
        tz = local_timezone()
        rows = service.calendar.events_between(datetime.combine(start, dtime.min, tzinfo=tz),
                                               datetime.combine(end + timedelta(days=1), dtime.min, tzinfo=tz),
                                               calendar_ids=calendar, tz=tz)
        return EventsOut(events=[EventOut(**r) for r in rows],
                         coverage=[CoverageOut(**c) for c in service.coverage(start, end)])

    _routes_mac(app, need)


def _routes_mac(app: FastAPI, need: Callable[[], SyncService]) -> None:
    """GET /sources and This Mac's settings. On a host that is not a Mac, the "mac" source is absent and its
    routes answer 404."""
    from ..sources.mac import MAC_ID
    from ..sources.mac.source import MacNotEnabled, MacUnavailable
    not_mac = {404: {"description": "this host is not a Mac: there is no This Mac source"},
               503: {"description": "accounts are not available in this host"}}

    def mac():
        source = need().mac
        if source is None or not source.available:
            raise HTTPException(404, "This host is not a Mac, so there is no This Mac source.")
        return source

    def icloud_rows(service: SyncService) -> list[SourceOut]:
        status = {r["account_id"]: r for r in service.status()}
        out = []
        for a in service.accounts.list():
            st = status.get(a.id, {})
            out.append(SourceOut(id=a.id, kind="icloud", enabled=True, email=a.email, notes_included=True,
                                 state=st.get("state"), last_update=st.get("last_success"),
                                 last_error=st.get("last_error"), counts=SyncCounts(**(st.get("counts") or {}))))
        return out

    @app.get("/sources", dependencies=needs("sources:read"), tags=["sources"], response_model=SourcesOut,
             responses={503: {"description": "accounts are not available in this host"}})
    def sources() -> SourcesOut:
        """Every source: This Mac first (only on a Mac host), then each linked iCloud account."""
        service = need()
        rows = []
        if service.mac is not None and service.mac.available:
            mac_row = service.mac.public()
            if service.mac.enabled:  # what it mirrored now; a source that is off holds nothing
                mac_row["counts"] = SyncCounts(**service.contacts.counts(MAC_ID), **service.calendar.counts(MAC_ID))
            rows.append(SourceOut(**mac_row))
        return SourcesOut(sources=[*rows, *icloud_rows(service)])

    @app.put("/sources/mac", dependencies=needs("sources:manage"), tags=["sources"], response_model=SourceOut,
             responses={**not_mac, 400: {"description": "the body is not valid"}})
    def configure_mac(body: MacSourceIn) -> SourceOut:
        """Turn This Mac on or off, and choose which contact accounts and calendars it includes (null: all).
        Fields left out keep their value. Turning it off stops its reader and deletes everything it mirrored;
        leaving out an account or calendar deletes what was mirrored from it. Copies in the host's snapshots
        stay until they expire (within 12 months while the host runs). With no source on, the host is back
        in demo mode."""
        source = mac()
        given = body.model_fields_set
        kwargs: dict = {}
        if "contact_containers" in given:
            kwargs["contact_containers"] = body.contact_containers
        if "calendars" in given:
            kwargs["calendars"] = body.calendars
        try:
            return SourceOut(**source.configure(enabled=body.enabled, **kwargs))
        except MacUnavailable:
            raise HTTPException(404, "This host is not a Mac, so there is no This Mac source.") from None

    @app.post("/sources/mac/request-access", dependencies=needs("sources:manage"),
              tags=["sources"], response_model=SourceOut,
              responses={**not_mac, 409: {"description": "This Mac is turned off"},
                         504: {"description": "the reader did not start"}})
    def request_mac_access(body: AccessIn) -> SourceOut:
        """Show the system's permission prompt for contacts or calendars. Only call this when the user pressed
        Allow. Waits for the answer (up to a few minutes) and returns the source with the new status."""
        source = mac()
        try:
            return SourceOut(**source.request_access(body.what))
        except MacNotEnabled:
            raise HTTPException(409, "Turn on This Mac first.") from None
        except TimeoutError as e:
            raise HTTPException(504, str(e)) from None

    @app.post("/sources/mac/sync", dependencies=needs("sources:manage"),
              tags=["sources"], response_model=SourceOut, status_code=202,
              responses={**not_mac, 409: {"description": "This Mac is turned off"}})
    def sync_mac() -> SourceOut:
        """Read the Mac's contacts and calendars again now, in the background."""
        try:
            return SourceOut(**mac().sync_now())
        except MacNotEnabled:
            raise HTTPException(409, "Turn on This Mac first.") from None

    @app.put("/sources/mac/reader", dependencies=needs("sources:manage"), tags=["sources"], response_model=SourceOut,
             responses={**not_mac, 400: {"description": "the path is not the reader"}})
    def set_mac_reader(body: ReaderIn) -> SourceOut:
        """Where the myData app's reader helper is (myData.app/Contents/Helpers/myDataReader.app). The myData
        app sends this at start; the host checks it is the reader before using it."""
        source = mac()
        try:
            source.set_reader_path(body.path)
        except ValueError as e:
            raise HTTPException(400, str(e)) from None
        return SourceOut(**source.public())


def _list_view(row: dict) -> dict:
    """A contact with what the contact list shows: its letter group and caption, its etag, and whether it is on
    a phone (an owned one is not, yet)."""
    from ..sources.views import contact_caption, sort_letter
    return {**row, "sort_letter": sort_letter(row["display_name"]),
            "caption": contact_caption(row["display_name"], row["organisation"], row["emails"], row["phones"]),
            "etag": row["http_etag"], "on_phone": False if row["editable"] else None}


def _detail(service: SyncService, row: dict, *, raw: bool = False) -> ContactDetailOut:
    """A contact for its page (GET /contacts/{id} and the answers of the writes)."""
    from ..sources import contact_form
    from ..sources.vcard import parse_vcard
    from ..sources.vcard_edit import VCard, VCardError
    from ..sources.views import contact_fields, source_in_sentence
    card = parse_vcard(row["raw_vcard"])
    try:
        form = contact_form.read(VCard.parse(row["raw_vcard"]))
    except VCardError:
        form = {}
    row = _list_view(row)
    emails = service.account_emails()
    changed = row.get("changed_in_source")
    row.update(source_label=source_in_sentence(row["account_id"], emails.get(row["account_id"])),
               changed_in_source_label=source_in_sentence(changed, emails.get(changed)) if changed else None,
               job_title=card.job_title, urls=card.urls,
               fields=contact_fields(row, urls=card.urls, notes_included=row["notes_included"]),
               **{k: form.get(k, "") for k in ("middle_name", "name_prefix", "name_suffix", "company", "department")})
    if not raw:
        row.pop("raw_vcard", None)
    return ContactDetailOut(**row)


def _routes_contact_writes(app: FastAPI, need: Callable[[], SyncService], unavailable: dict) -> None:
    """Creating, changing and deleting the contacts the host owns, Recently deleted, and undo
    (sources/contacts_write.py). Followed contacts are never changed: 409."""
    from ..sources import contacts_write as cw
    from ..sources.contact_form import FormError

    etag_header = {"ETag": {"description": "the contact's etag", "schema": {"type": "string"}}}
    refused = {404: {"description": "no such contact"},
               409: {"description": "the contact is followed from a source (change it there), or is in Recently "
                                    "deleted"}}
    invalid = {400: {"model": FieldErrorsOut, "description": "a field is not valid; `fields` says which and why"}}
    stale = {412: {"model": PreconditionFailedOut, "headers": etag_header,
                   "description": "the contact changed since the etag sent; `etag` is the current one"}}

    def actor(request: Request) -> str:
        return request.state.principal.name

    def answer(service: SyncService, written: "cw.Written", op: str, who: str, response: Response | None = None
               ) -> ContactWriteOut:
        log(_LOGGER, logging.INFO, "contact written", op=op, actor=who, contact_id=written.contact_id)
        if written.book_created:  # owned data appeared: the host switches to real mode, as turning a source on does
            service.owned_data_changed()
        detail = _detail(service, service.contacts.get(written.contact_id, include_deleted=True))
        if response is not None:
            response.headers["ETag"] = detail.etag
        return ContactWriteOut(contact=detail, undo_id=written.undo_id)

    def run(write: Callable[[], "cw.Written"]) -> "cw.Written":
        try:
            return write()
        except FormError as e:
            raise _JSONError(400, {"detail": "Some fields are not valid.", "fields": e.fields}) from None
        except cw.PreconditionFailed as e:
            raise _JSONError(412, {"detail": str(e), "etag": e.etag}, headers={"ETag": e.etag}) from None
        except cw.NotFound as e:
            raise HTTPException(404, str(e)) from None
        except cw.WriteError as e:  # followed, in the trash, cannot be undone
            raise HTTPException(409, str(e)) from None

    @app.post("/contacts", dependencies=needs("contacts:write"), tags=["sources"], response_model=ContactWriteOut,
              status_code=201, responses={201: {"headers": etag_header}, **invalid, **unavailable})
    def create_contact(body: ContactIn, request: Request, response: Response) -> ContactWriteOut:
        """Create a contact the host owns, in its "myData" address book (made with the first contact, which also
        switches the host to real mode). It is on myData only, not on any phone yet (on_phone false)."""
        service = need()
        who = actor(request)
        written = run(lambda: cw.create(service.contacts, body.model_dump(exclude_unset=True), actor=who))
        return answer(service, written, "create", who, response)

    @app.patch("/contacts/{contact_id}", dependencies=needs("contacts:write"), tags=["sources"],
               response_model=ContactWriteOut,
               responses={200: {"headers": etag_header}, **invalid, **refused, **stale,
                          428: {"description": "If-Match is missing"}, **unavailable})
    def update_contact(contact_id: str, body: ContactIn, request: Request, response: Response,
                       if_match: str | None = Header(default=None, alias="If-Match",
                                                     description="the etag the change was made from")
                       ) -> ContactWriteOut:
        """Change an owned contact. Only the fields in the body change (null clears one), and of the card only
        the lines whose values change are written. Refused with 412 when the contact changed since its etag."""
        if not if_match:
            raise HTTPException(428, "Send the contact's etag as If-Match.")
        service = need()
        who = actor(request)
        written = run(lambda: cw.update(service.contacts, contact_id, body.model_dump(exclude_unset=True),
                                        if_match=if_match, actor=who))
        return answer(service, written, "update", who, response)

    @app.delete("/contacts/{contact_id}", dependencies=needs("contacts:write"), tags=["sources"],
                response_model=ContactWriteOut,
                responses={**refused, **stale, 428: {"description": "If-Match is missing"}, **unavailable})
    def delete_contact(contact_id: str, request: Request,
                       if_match: str | None = Header(default=None, alias="If-Match",
                                                     description="the etag of the contact the user chose to delete")
                       ) -> ContactWriteOut:
        """Move an owned contact to Recently deleted. It is deleted for good after 30 days (purge_after); until
        then POST /trash/{id}/restore or the undo id brings it back. Refused with 412 when the contact changed
        since its etag. Copies in the host's snapshots stay until those expire (within 12 months while the host
        runs)."""
        if not if_match:
            raise HTTPException(428, "Send the contact's etag as If-Match.")
        service = need()
        who = actor(request)
        written = run(lambda: cw.delete(service.contacts, contact_id, if_match=if_match, actor=who))
        return answer(service, written, "delete", who)

    @app.get("/trash", dependencies=needs("contacts:read"), tags=["sources"], response_model=list[TrashItemOut],
             responses=unavailable)
    def trash(kind: Literal["contact"] = Query(default="contact", description="what to list")) -> list[TrashItemOut]:
        """Recently deleted: what was deleted in the apps, the most recent first, with when each is deleted for
        good. Copies in the host's snapshots stay until those expire."""
        rows = cw.trash(need().contacts)
        kept = kept_until().isoformat()
        return [TrashItemOut(id=r["id"], kind="contact", title=r["display_name"], deleted_at=r["deleted_at"],
                             purge_after=r["purge_after"] or "", backups_kept_until=kept,
                             contact=ContactOut(**_list_view(r))) for r in rows]

    @app.delete("/trash/{item_id}", dependencies=needs("contacts:write"), tags=["sources"], status_code=204,
                responses={404: {"description": "no such item in Recently deleted"},
                           409: {"description": "the contact is followed from a source"}, **stale,
                           428: {"description": "If-Match is missing"}, **unavailable})
    def purge_item(item_id: str, request: Request,
                   if_match: str | None = Header(default=None, alias="If-Match",
                                                 description="the item's etag as Recently deleted lists it "
                                                             "(contact.etag)")) -> Response:
        """Delete an item in Recently deleted for good now, with its earlier versions; it cannot be brought back
        or undone. Refused with 412 when the item changed since its etag (restored, changed and deleted again
        elsewhere): look at it again first. The host log records which app asked. Copies in the host's
        snapshots stay until those expire (backups_kept_until)."""
        if not if_match:
            raise HTTPException(428, "Send the item's etag as If-Match.")
        service = need()
        who = actor(request)
        try:
            cw.purge_now(service.contacts, item_id, if_match=if_match)
        except cw.PreconditionFailed as e:
            raise _JSONError(412, {"detail": str(e), "etag": e.etag}, headers={"ETag": e.etag}) from None
        except cw.NotFound as e:
            raise HTTPException(404, str(e)) from None
        except cw.WriteError as e:
            raise HTTPException(409, str(e)) from None
        log(_LOGGER, logging.INFO, "contact purged", actor=who, contact_id=item_id)
        service.owned_data_changed()  # owned data was purged: the mode follows what is left
        return Response(status_code=204)

    @app.post("/trash/{item_id}/restore", dependencies=needs("contacts:write"), tags=["sources"],
              response_model=ContactWriteOut, responses={**refused, **stale, **unavailable})
    def restore_item(item_id: str, request: Request,
                     if_match: str | None = Header(default=None, alias="If-Match",
                                                   description="optional: the item's etag as Recently deleted lists "
                                                               "it; refuse if it changed since")
                     ) -> ContactWriteOut:
        """Bring an item back from Recently deleted. 404 when it is not there (or was deleted for good); 412 when
        If-Match is sent and the item changed since."""
        service = need()
        who = actor(request)
        written = run(lambda: cw.restore(service.contacts, item_id, if_match=if_match, actor=who))
        return answer(service, written, "restore", who)

    @app.post("/undo/{undo_id}", dependencies=needs("contacts:write"), tags=["sources"], response_model=UndoOut,
              responses={404: {"description": "no such undo id"},
                         409: {"description": "already undone, or the item changed since (or was deleted for good)"},
                         **unavailable})
    def undo(undo_id: str, request: Request) -> UndoOut:
        """Undo one change by its undo id, a merge's too. The undo is a new change: it is refused when the item
        changed since (nothing later is ever overwritten), and a change is undone at most once, also across a
        restart. Undoing a merge restores each original and moves the merged contact to Recently deleted."""
        from ..sources import contacts_merge
        service = need()
        who = actor(request)
        if contacts_merge.is_merge(service.contacts, undo_id):
            merged = run(lambda: contacts_merge.undo(service.contacts, undo_id, actor=who))
            log(_LOGGER, logging.INFO, "contacts merge undone", actor=who, merge_id=undo_id)
            first = _detail(service, service.contacts.get(merged.originals[0], include_deleted=True))
            return UndoOut(undo_id=undo_id, contact=first, contact_ids=[*merged.originals, merged.contact_id])
        written = run(lambda: cw.undo(service.contacts, undo_id, actor=who))
        out = answer(service, written, "undo", who)
        return UndoOut(undo_id=undo_id, contact=out.contact, contact_ids=[written.contact_id])

    @app.post("/contacts/merge", dependencies=needs("contacts:write"), tags=["sources"], response_model=MergeOut,
              status_code=201, responses={400: {"description": "fewer than two contacts, one named twice, or "
                                                               "names_from not among them"},
                                          **refused, **stale, **unavailable})
    def merge_contacts(body: MergeIn, request: Request) -> MergeOut:
        """Merge owned contacts the user chose as one person (never automatic): a new contact holds the first
        one's names (or names_from's) and every email, phone, address and link of them all; the originals go to
        Recently deleted, unchanged, so POST /undo/{undo_id} brings them back while nothing changed since. 412 when
        a contact changed since its etag."""
        from ..sources import contacts_merge
        service = need()
        who = actor(request)

        def write() -> "contacts_merge.Merged":
            try:
                return contacts_merge.merge(service.contacts, [(c.id, c.etag) for c in body.contacts],
                                            names_from=body.names_from, actor=who)
            except contacts_merge.MergeRefused as e:
                raise HTTPException(400, str(e)) from None

        merged = run(write)
        log(_LOGGER, logging.INFO, "contacts merged", actor=who, contact_id=merged.contact_id,
            merge_id=merged.merge_id, count=len(merged.originals))
        detail = _detail(service, service.contacts.get(merged.contact_id))
        return MergeOut(contact=detail, undo_id=merged.merge_id, merged=list(merged.originals))


def _routes_imports(app: FastAPI, need: Callable[[], SyncService], unavailable: dict) -> None:
    """Contact import (sources/importer.py, service/imports.py): an app action, never a tool, so MCP agents (and
    the assistant) get nothing; contacts:write only."""
    from fastapi.concurrency import run_in_threadpool

    from ..sources import contacts_write as cw
    from ..sources import importer
    from ..sources.import_files import MAX_INPUT, ImportFileError
    from .imports import ContactImports, NotImportable, PreviewGone, SnapshotFailed

    held: dict[str, ContactImports] = {}
    lock = threading.Lock()
    gone = {404: {"description": "no such preview: it expired, was imported already, or the host restarted"}}

    def imports() -> ContactImports:
        service = need()
        with lock:
            if "imports" not in held:
                held["imports"] = ContactImports(service)
            return held["imports"]

    def actor(request: Request) -> str:
        return request.state.principal.name

    def run(work: Callable[[], Any]) -> Any:
        try:
            return work()
        except PreviewGone as e:
            raise HTTPException(404, str(e)) from None
        except ImportFileError as e:
            raise HTTPException(400, str(e)) from None
        except (importer.LossesNotAccepted, importer.ChoiceError) as e:
            raise HTTPException(400, str(e)) from None
        except SnapshotFailed as e:
            raise HTTPException(503, str(e)) from None
        except cw.NotFound as e:
            raise HTTPException(404, str(e)) from None
        except cw.WriteError as e:  # already undone
            raise HTTPException(409, str(e)) from None

    body_schema = {"requestBody": {"required": True, "description": "the file's bytes as they are (a .vcf, or a "
                                                                    ".zip of .vcf files), at most 50 MB",
                                   "content": {"application/octet-stream": {"schema": {"type": "string",
                                                                                       "format": "binary"}}}}}

    @app.post("/import/contacts/preview", dependencies=needs("contacts:write"), tags=["imports"],
              response_model=ImportPreviewOut, status_code=201, openapi_extra=body_schema,
              responses={400: {"description": "the file cannot be imported at all (not a vCard, a zip that cannot "
                                              "be read or expands too far); the message says why"},
                         413: {"description": "the file is larger than 50 MB"}, **unavailable})
    async def preview_contacts_import(request: Request,
                                      filename: str = Query(default="", max_length=255,
                                                            description="the file's name, shown in the history; "
                                                                        "never opened as a path")
                                      ) -> ImportPreviewOut:
        """Read a .vcf (vCard 2.1, 3.0 or 4.0) or a .zip of them, sent as the request body, into a preview held for
        an hour: counts, every card's status and default action, matches with your contacts and followed ones,
        the loss report and what changes. Nothing is written. The zip is read in memory, never extracted."""
        length = request.headers.get("content-length")
        if length is not None and length.isdigit() and int(length) > MAX_INPUT:
            raise HTTPException(413, "The file is larger than 50 MB.")
        chunks, size = [], 0
        async for chunk in request.stream():
            size += len(chunk)
            if size > MAX_INPUT:
                raise HTTPException(413, "The file is larger than 50 MB.")
            chunks.append(chunk)
        service, who = imports(), actor(request)
        data = b"".join(chunks)
        out = await run_in_threadpool(run, lambda: service.preview_file(data, filename, who))
        return ImportPreviewOut(**out)

    @app.post("/import/contacts/from-source/{account_id}/preview", dependencies=needs("contacts:write"),
              tags=["imports"], response_model=ImportPreviewOut, status_code=201,
              responses={404: {"description": "no such account"},
                         409: {"description": "This Mac is never imported; the message says why and what to do "
                                              "instead"}, **unavailable})
    def preview_source_import(account_id: str, request: Request) -> ImportPreviewOut:
        """A preview of importing a copy of a followed iCloud account's contacts (as the mirror holds them, so
        nothing is lost). Once imported, each followed card is hidden behind its owned copy while the account is
        still followed; stop_following says the account can be unfollowed. This Mac is never imported (409)."""
        service, who = imports(), actor(request)
        try:
            return ImportPreviewOut(**run(lambda: service.preview_source(account_id, who)))
        except NotImportable as e:
            raise HTTPException(409, str(e)) from None
        except KeyError:
            raise HTTPException(404, "no such account") from None

    @app.get("/import/previews/{preview_id}", dependencies=needs("contacts:write"), tags=["imports"],
             response_model=ImportPreviewOut, responses={**gone, **unavailable})
    def import_preview(preview_id: str) -> ImportPreviewOut:
        """A preview again, analysed as the host is now."""
        service = imports()
        return ImportPreviewOut(**run(lambda: service.get(preview_id)))

    @app.post("/import/previews/{preview_id}/commit", dependencies=needs("contacts:write"), tags=["imports"],
              response_model=ImportCommittedOut, status_code=201,
              responses={**gone, 400: {"description": "losses not accepted, or a choice a card cannot take"},
                         503: {"description": "the snapshot before the import failed: nothing was imported"}})
    def commit_import(preview_id: str, body: ImportCommitIn, request: Request) -> ImportCommittedOut:
        """Import the preview as one batch into an owned address book, after a snapshot of the databases. Each card
        gets its default action unless `choices` names another; nothing is merged. A preview with losses needs
        accept_losses. Cards that changed both in the input and on the host since an earlier import are reported
        as conflicts and not written; contacts an earlier import brought in that the input no longer has are
        reported as missing and kept. POST /imports/{id}/undo undoes the whole import."""
        service, who = imports(), actor(request)
        choices = {c.index: c.action for c in body.choices}
        out = run(lambda: service.commit(preview_id, address_book_id=body.address_book_id, choices=choices,
                                         accept_losses=body.accept_losses, actor=who))
        return ImportCommittedOut(**out)

    @app.get("/imports", dependencies=needs("contacts:write"), tags=["imports"], response_model=list[ImportOut],
             responses=unavailable)
    def import_history() -> list[ImportOut]:
        """Every import, the newest first: when, from where, its counts and whether it was undone."""
        return [ImportOut(**r) for r in imports().history()]

    @app.post("/imports/{import_id}/undo", dependencies=needs("contacts:write"), tags=["imports"],
              response_model=ImportUndoneOut,
              responses={404: {"description": "no such import"}, 409: {"description": "already undone"},
                         **unavailable})
    def undo_import(import_id: str, request: Request) -> ImportUndoneOut:
        """Undo a whole import: what it created and nobody changed since goes to Recently deleted, what it updated
        gets its earlier text back. Anything changed since is kept and listed. Nothing is deleted for good. Works
        once, also after a restart."""
        service, who = imports(), actor(request)
        return ImportUndoneOut(**run(lambda: service.undo(import_id, who)))


class _JSONError(HTTPException):
    """An HTTPException whose body is `content` as it is (not wrapped in "detail")."""

    def __init__(self, status: int, content: dict, headers: dict | None = None):
        super().__init__(status, content.get("detail", ""), headers=headers)
        self.content = content


def _status_rows(need: Callable[[], SyncService]) -> list[dict]:
    try:
        service = need()
    except HTTPException:
        return []
    return service.status()


def _mcp_endpoint(session_manager):
    async def endpoint(scope, receive, send):
        await session_manager.handle_request(scope, receive, send)
    # A class instance would be treated as a raw ASGI app; wrap the function the same way.
    return _ASGI(endpoint)


class _ASGI:
    def __init__(self, fn):
        self.fn = fn

    async def __call__(self, scope, receive, send):
        await self.fn(scope, receive, send)


async def _sse(assistant: Assistant, text: str, conversation_id: str | None):
    """Run the blocking assistant in a thread and forward its events as SSE."""
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()
    done = object()

    def work() -> None:
        try:
            for event in assistant.reply(text, conversation_id):
                loop.call_soon_threadsafe(queue.put_nowait, event)
        except Exception as e:  # never leave the stream hanging
            loop.call_soon_threadsafe(queue.put_nowait, {"type": "error", "message": f"{type(e).__name__}: {e}"})
            loop.call_soon_threadsafe(queue.put_nowait, {"type": "done"})
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, done)

    threading.Thread(target=work, name="sse", daemon=True).start()
    while True:
        event = await queue.get()
        if event is done:
            return
        kind = event.pop("type")
        yield f"event: {kind}\ndata: {json.dumps(event, ensure_ascii=False, default=str)}\n\n"
