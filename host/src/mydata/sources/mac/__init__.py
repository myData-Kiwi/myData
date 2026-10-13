"""The "This Mac" source: contacts and calendars read from macOS itself (Contacts and EventKit), through
the myDataReader helper app inside the myData app. The host side: the socket the helper connects to
(socket.py), how the helper is started (launcher.py), the messages (protocol.py) and the source itself
(source.py), which writes what the helper reads into the existing contacts and calendar mirrors."""

MAC_ID = "mac"  # the source id, and the account_id of its rows in contacts.sqlite and calendar.sqlite
