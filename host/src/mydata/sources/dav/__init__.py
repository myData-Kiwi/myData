"""A small, read-only CardDAV/CalDAV client.

client.py holds the one place any HTTP request is made (DavClient.request), and it refuses every
method except PROPFIND, REPORT, OPTIONS and GET. discovery.py finds the principal, home sets and
collections; sync.py mirrors a collection's items (RFC 6578 sync tokens, or ctag/etag listing).
"""
