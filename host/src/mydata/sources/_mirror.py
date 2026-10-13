"""Collection bookkeeping shared by the contacts and calendar mirrors: one row per synced collection
holding its name, colour and sync state; soft-deleting what upstream no longer has."""

from __future__ import annotations

import json

from ._db import new_id
from .dav.discovery import Collection
from .dav.sync import CollectionState

def upsert_collection(db, table: str, account_id: str, collection: Collection, state: CollectionState,
                       stamp: str) -> str:
    """Create or refresh a collection row (name, colour, sync state) and return its device-generated id."""
    etags = json.dumps(dict(state.etags or {}), ensure_ascii=False, sort_keys=True)
    row = db.execute(f"SELECT id FROM {table} WHERE account_id = ? AND url = ?", (account_id, collection.url)).fetchone()
    if row is None:
        collection_id = new_id()
        db.execute(
            f"INSERT INTO {table} (id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (collection_id, account_id, collection.url, collection.display_name or "", collection.color,
             state.sync_token, state.ctag, etags, stamp, stamp),
        )
        return collection_id
    db.execute(
        f"UPDATE {table} SET name = ?, color = ?, sync_token = ?, ctag = ?, etags = ?, modified_at = ?, "
        "deleted_at = NULL WHERE id = ?",
        (collection.display_name or "", collection.color, state.sync_token, state.ctag, etags, stamp, row["id"]),
    )
    return row["id"]


def load_state(db, table: str, account_id: str, url: str) -> CollectionState:
    row = db.execute(
        f"SELECT sync_token, ctag, etags FROM {table} WHERE account_id = ? AND url = ? AND deleted_at IS NULL",
        (account_id, url),
    ).fetchone()
    if row is None:
        return CollectionState()
    return CollectionState(sync_token=row["sync_token"], ctag=row["ctag"], etags=json.loads(row["etags"] or "{}"))


def soft_delete_missing(db, table: str, account_id: str, collection_url: str, present: set[str], stamp: str) -> None:
    rows = db.execute(
        f"SELECT id, href FROM {table} WHERE account_id = ? AND collection_url = ? AND deleted_at IS NULL",
        (account_id, collection_url),
    ).fetchall()
    gone = [(stamp, stamp, r["id"]) for r in rows if r["href"] not in present]
    db.executemany(f"UPDATE {table} SET deleted_at = ?, modified_at = ? WHERE id = ?", gone)


def retire_collections(db, table: str, items: str, fk: str, account_id: str, present: set[str], stamp: str) -> None:
    rows = db.execute(
        f"SELECT id, url FROM {table} WHERE account_id = ? AND deleted_at IS NULL", (account_id,)
    ).fetchall()
    for r in rows:
        if r["url"] in present:
            continue
        db.execute(
            f"UPDATE {table} SET deleted_at = ?, modified_at = ?, sync_token = NULL, ctag = NULL, etags = '{{}}' "
            "WHERE id = ?",
            (stamp, stamp, r["id"]),
        )
        db.execute(
            f"UPDATE {items} SET deleted_at = ?, modified_at = ? WHERE {fk} = ? AND deleted_at IS NULL",
            (stamp, stamp, r["id"]),
        )
