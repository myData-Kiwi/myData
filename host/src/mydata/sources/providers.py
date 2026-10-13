"""Account providers. iCloud is the only one: its two discovery start URLs are the only fixed values;
everything after them (principal, home sets, partition hosts, collections) is discovered.

verify_icloud() is the check `Accounts.add` runs before anything is stored: discovery of both the
contacts and the calendar side must succeed with the given email and app-specific password.
"""

from __future__ import annotations

ICLOUD = {"contacts": "https://contacts.icloud.com", "calendar": "https://caldav.icloud.com"}

PROVIDERS = {"icloud": ICLOUD}
PROVIDER_NAMES = {"icloud": "iCloud"}
APP_PASSWORD_HELP = ("Use the email of your Apple Account (the one you sign in to Apple with, which may differ "
                     "from an address on your own domain) and an app-specific password, not your Apple Account "
                     "password. Make one at https://account.apple.com (Sign-In and Security > App-Specific "
                     "Passwords).")
# The sign-in was refused (HTTP 401 or 403). A common cause: an iCloud+ custom-domain address, which is
# not the Apple Account's sign-in email.
REJECTED = ("Apple did not accept this sign-in. Use the email of your Apple Account, which may differ from an "
            "address on your own domain, and an app-specific password made at account.apple.com.")


class VerificationError(Exception):
    """The account could not be verified. The message is safe to show: it never contains the password."""


def _redact(text: str, password: str) -> str:
    return text.replace(password, "***") if password else text


def verify_icloud(email: str, password: str, *, transport=None) -> None:
    """Run discovery for contacts and calendars; raise VerificationError if either fails.
    `transport` (an httpx transport) is for tests."""
    # Imported here: the DAV client is its own module and is only needed when an account is added.
    from .dav.client import DavClient, DavError
    from .dav.discovery import discover

    client = DavClient(email, password, transport=transport)
    try:
        for kind in ("contacts", "calendar"):
            try:
                discover(client, ICLOUD[kind], kind)
            except DavError as e:
                status = getattr(e, "status", None)
                if status in (401, 403):
                    raise VerificationError(REJECTED) from None
                if status is None:  # a network failure: nothing was answered
                    raise VerificationError(f"Could not reach iCloud {kind}. Check the connection and try "
                                            "again.") from None
                raise VerificationError(f"iCloud {kind} discovery failed (HTTP {status}).") from None
            except VerificationError:
                raise
            except Exception as e:  # network errors, malformed replies: say what kind, never the password
                detail = _redact(str(e), password)[:200]
                raise VerificationError(f"Could not reach iCloud {kind}: {type(e).__name__}"
                                        + (f": {detail}" if detail else "")) from None
    finally:
        client.close()


VERIFIERS = {"icloud": verify_icloud}
