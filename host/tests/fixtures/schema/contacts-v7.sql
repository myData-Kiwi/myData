-- Synthetic contacts.sqlite at schema version 7, written by make_dump.py. Invented data only.
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (1, 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'acc-1', 'https://contacts.example.com/1/carddavhome/card/', 'Card', NULL, 't1', NULL, '{"/1/carddavhome/card/ava-fictional.vcf": "\"2\""}', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (2, '01174d76-1310-478b-9f6e-4c72f2358c04', 'acc-2', 'https://contacts.example.com/1/carddavhome/work/', 'Work', NULL, 't1', NULL, '{"/2/card/zoe.vcf": "\"1\""}', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (3, '900aab94-b803-4900-94ee-15e0978be8b9', 'mac', 'mac://contacts/container-icloud-0001', 'container-icloud-0001', NULL, NULL, NULL, '{"contact-ava-0001": "650fe18de1d16a3867cbba7e859e00a0", "contact-sam-0002": "1fb626b2c74fe2a59863c44f670d4704"}', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (4, 'ecab0464-93f6-4448-ae9f-b1195749135f', 'mac', 'mac://contacts/container-local-0002', 'container-local-0002', NULL, NULL, NULL, '{"contact-acme-0003": "0bcffba0f5ac233abc48214e5240266d", "contact-sam-0004": "eefd0483689400e1d4d58d5f3045d3b7"}', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (5, 'owned-book-1', 'local', 'owned://contacts/book-1', 'Kept (owned)', NULL, NULL, NULL, '{}', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 'owned');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (6, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'local', 'owned://contacts/mydata', 'myData', NULL, NULL, NULL, '{}', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 'owned');
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (1, '08a764e8-ef05-40c2-886e-12f2c756bf1e', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/ava-fictional.vcf', '"2"', '3F1C0F0E-0000-4000-8000-00000000A001', 'Ava Fictional', 'Ava Fictional', 'Ava', 'Fictional', 'Avi B', 'Example Widgets, Research', '[{"value": "ava@example.com", "label": "work"}, {"value": "ava.home@example.net", "label": "home"}, {"value": "ava.club@example.org", "label": "Chess club"}]', '[{"value": "+1 (555) 010-0100", "label": "mobile"}, {"value": "+44 20 7946 0000", "label": "home"}, {"value": "+1 555 0199", "label": "Gym locker"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Springfield", "region": "", "postal_code": "12345", "country": "Exampleland"}]', '--04-15', 'Met at the invented conference, row two.
Brings biscuits.', 1, 'BEGIN:VCARD
VERSION:3.0
PRODID:-//Apple Inc.//iPhone OS 17.0//EN
N:Fictional;Ava;;;
FN:Ava Fictional
NICKNAME:Avi B
ORG:Example Widgets;Research
item1.EMAIL;type=INTERNET;type=pref:ava@example.com
item1.X-ABLabel:_$!<Work>!$_
EMAIL;type=INTERNET;type=HOME:ava.home@example.net
item2.EMAIL;type=INTERNET:ava.club@example.org
item2.X-ABLabel:Chess club
TEL;type=CELL;type=VOICE;type=pref:+1 (555) 010-0100
TEL;type=HOME;type=VOICE:+44 20 7946 0000
item3.TEL:+1 555 0199
item3.X-ABLabel:Gym locker
item4.ADR;type=HOME;type=pref:;;1 Example Street;Springfield;;12345;Exampleland
item4.X-ABADR:us
BDAY;X-APPLE-OMIT-YEAR=1604:1604-04-15
NOTE:Met at the invented conference\, row two.\nBrings biscuits.
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDAsMDQ0MDQ4P
 DxAQEBEREhITExMUFBQVFRUWFhYXFxcYGBgZGRka
UID:3F1C0F0E-0000-4000-8000-00000000A001
X-ABUID:3F1C0F0E-0000-4000-8000-00000000A001:ABPerson
END:VCARD
', 'ava@example.com ava.home@example.net ava.club@example.org', CAST(X'2B31202835353529203031302D30313030202B343420323020373934362030303030202B3120353535203031393920313535353031303031303020353535303130303130302035353031303031303020353031303031303020303130303130302034343230373934363030303020343230373934363030303020323037393436303030302030373934363030303020373934363030303020393436303030302031353535303139392035353530313939' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 2, 'a1eeef6b5b913cdb70c186c31c7aaf3b0e07c970cc37ad92c9c42c221f125d5a', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (2, '4370601f-546b-4f82-9886-f71d86b37f67', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/zoe-example-v4.vcf', '"1"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
VERSION:4.0
UID:urn:uuid:00000000-0000-4000-8000-00000000a002
FN:Zoë Exämple
N:Exämple;Zoë;;;
EMAIL;TYPE=work;PREF=1:zoe@example.org
EMAIL;TYPE=home:zoe.home@example.net
TEL;VALUE=uri;TYPE="voice,cell":tel:+44-20-7946-0123
BDAY:19900401
PHOTO:data:image/png;base64,iVBORw0KGgo=
END:VCARD
', 'zoe@example.org zoe.home@example.net', CAST(X'2B34342D32302D373934362D30313233203434323037393436303132332034323037393436303132332032303739343630313233203037393436303132332037393436303132332039343630313233' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (3, 'd72ecede-9832-4993-9048-df583771612e', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/org-only.vcf', '"1"', '00000000-0000-4000-8000-00000000a003', 'Example Bakery Ltd', '', '', '', '', 'Example Bakery Ltd', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '602ead1aafe389bcabfe067ed80bfa02b7d4a075274b4b3787a6b0aaac17ee54', NULL, 'org', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (4, 'df410f95-9029-4026-ac7e-2104d0656245', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/phone-only.vcf', '"1"', '00000000-0000-4000-8000-00000000a004', '+1 555 0177', '', '', '', '', '', '[]', '[{"value": "+1 555 0177", "label": "mobile"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
TEL;type=CELL:+1 555 0177
UID:00000000-0000-4000-8000-00000000a004
END:VCARD
', '', CAST(X'2B312035353520303137372031353535303137372035353530313737' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 1, '80c9e5e4a328298b6448a8270c22c2ca9ebc2bd2f72ae4e7e51bb5cf23867977', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (5, '27f0d418-9cac-4c5e-b4e2-6a428478d57e', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/empty.vcf', '"1"', '00000000-0000-4000-8000-00000000a005', 'No name', '', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, 'e56104f08ffb716728f06c038e0e9304bb94f29ad1d0439e6d518a488e7d5231', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (6, '3aef1b01-655f-4ef1-9ee0-381293a715f3', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/sam-sample-1.vcf', '"1"', '00000000-0000-4000-8000-00000000a006', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '7e9a392c197a4d607c61b3f364a50cb309af8cc93793491b14bd435ee8be33e5', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (7, 'f37239a3-c633-4e88-b159-dbe205ab086b', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/sam-sample-2.vcf', '"1"', '00000000-0000-4000-8000-00000000a007', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '65a38df8888f338c4604106e3082f66325da9fd0be48660b86c24175b2fd7fbf', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (8, '753d7a72-0430-421e-81e4-e1292e3c3b2b', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/group-3.vcf', '"x0"', 'group-book-club@example.org', 'Book club', 'Book club', '', 'Book club', '', '', '[]', '[]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '8cc88a6e32584ccbf95df6c18d9ec933e203008b9d96538449eb9ce745835f18', NULL, 'group', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (9, '760a882d-b309-4fec-904c-c1b96d166960', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/group-4.vcf', '"x1"', 'urn:uuid:group-choir-1', 'Choir (example)', 'Choir (example)', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '9a18e2ccfc36bd19c9fba4bf7bb9fbf5f888091378ba5e9e4fbf4949e81bf66c', NULL, 'group', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (10, 'b3c572b9-390a-4cf6-9ce6-cc46c85cdd9a', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/org-4.vcf', '"x2"', 'urn:uuid:org-library-1', 'Example Library', 'Example Library', '', '', '', 'Example Library', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '2001e615e3fc5dfa816cba133c4e9eb431044e95095c523081dee3690f34432f', NULL, 'org', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (11, 'a0af09fe-5b58-4551-9e18-08af33822eea', 'acc-1', 'f24a62f2-ae2d-464a-983c-468ac52855e1', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/kim.vcf', '"x3"', 'kim-invented@example.org', 'Kim Invented', 'Kim Invented', 'Kim', 'Invented', '', '', '[{"value": "kim@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'kim@example.invalid', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '8839c761111c08e401bb7dce974bf74c3a7c89a239f9719a1d379782a283db8e', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (12, 'c9de094b-91ba-476d-bcd9-d10f53789811', 'acc-2', '01174d76-1310-478b-9f6e-4c72f2358c04', 'https://contacts.example.com/1/carddavhome/work/', '/2/card/zoe.vcf', '"1"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
VERSION:4.0
UID:urn:uuid:00000000-0000-4000-8000-00000000a002
FN:Zoë Exämple
N:Exämple;Zoë;;;
EMAIL;TYPE=work;PREF=1:zoe@example.org
EMAIL;TYPE=home:zoe.home@example.net
TEL;VALUE=uri;TYPE="voice,cell":tel:+44-20-7946-0123
BDAY:19900401
PHOTO:data:image/png;base64,iVBORw0KGgo=
END:VCARD
', 'zoe@example.org zoe.home@example.net', CAST(X'2B34342D32302D373934362D30313233203434323037393436303132332034323037393436303132332032303739343630313233203037393436303132332037393436303132332039343630313233' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (13, 'db7f1269-6375-4eeb-8dc1-02296f346ff5', 'mac', '900aab94-b803-4900-94ee-15e0978be8b9', 'mac://contacts/container-icloud-0001', 'contact-ava-0001', '650fe18de1d16a3867cbba7e859e00a0', 'contact-ava-0001', 'Ava Q Fictional', 'Ava Q Fictional', 'Ava', 'Fictional', 'Avi', 'Example Labs', '[{"value": "ava.fictional@example.com", "label": "home"}, {"value": "ava@work.example.net", "label": "work"}]', '[{"value": "+1 202 555 0101", "label": "mobile"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Testville", "region": "", "postal_code": "00000", "country": "Exampleland"}]', '1990-04-12', '', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D6176612D303030310D0A464E3A41766120512046696374696F6E616C0D0A4E3A46696374696F6E616C3B4176613B513B3B0D0A4E49434B4E414D453A4176690D0A4F52473A4578616D706C65204C6162730D0A5449544C453A496E76656E746F720D0A6974656D312E454D41494C3B545950453D494E5445524E45543A6176612E66696374696F6E616C406578616D706C652E636F6D0D0A6974656D312E582D41424C6162656C3A5F24213C486F6D653E21245F0D0A6974656D322E454D41494C3B545950453D494E5445524E45543A61766140776F726B2E6578616D706C652E6E65740D0A6974656D322E582D41424C6162656C3A5F24213C576F726B3E21245F0D0A6974656D332E54454C3A2B31203230322035353520303130310D0A6974656D332E582D41424C6162656C3A5F24213C4D6F62696C653E21245F0D0A6974656D342E4144523A3B3B31204578616D706C65205374726565743B5465737476696C6C653B3B30303030303B4578616D706C656C616E640D0A6974656D342E582D41424C6162656C3A5F24213C486F6D653E21245F0D0A424441593A313939302D30342D31320D0A6974656D352E55524C3A68747470733A2F2F7777772E6578616D706C652E6F72672F6176610D0A6974656D352E582D41424C6162656C3A686F6D65706167650D0A50484F544F3B454E434F44494E473D623B545950453D4A5045473A2F396A2F34476C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F0D0A20623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D0D0A2056756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A350D0A206447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C662F5A0D0A454E443A56434152440D0A' AS TEXT), 'ava.fictional@example.com ava@work.example.net', CAST(X'2B31203230322035353520303130312031323032353535303130312032303235353530313031203032353535303130312032353535303130312035353530313031' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '650fe18de1d16a3867cbba7e859e00a0e9126d35333ed37771e9f9584f9ec1a1', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (14, '6e005e6d-6688-4db1-8142-7ee77b8a9618', 'mac', '900aab94-b803-4900-94ee-15e0978be8b9', 'mac://contacts/container-icloud-0001', 'contact-sam-0002', '1fb626b2c74fe2a59863c44f670d4704', 'contact-sam-0002', 'Sam Example', 'Sam Example', 'Sam', 'Example', '', '', '[{"value": "sam.example@example.com", "label": ""}]', '[]', '[]', '--07-04', '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D73616D2D303030320D0A464E3A53616D204578616D706C650D0A4E3A4578616D706C653B53616D3B3B3B0D0A6974656D312E454D41494C3B545950453D494E5445524E45543A73616D2E6578616D706C65406578616D706C652E636F6D0D0A424441593A2D2D30372D30340D0A454E443A56434152440D0A' AS TEXT), 'sam.example@example.com', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '1fb626b2c74fe2a59863c44f670d47041a06bac5bbf6d0ec761619017fd6247a', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (15, 'c85816c1-158b-4c18-a4ed-fb0660bc3edc', 'mac', 'ecab0464-93f6-4448-ae9f-b1195749135f', 'mac://contacts/container-local-0002', 'contact-acme-0003', '0bcffba0f5ac233abc48214e5240266d', 'contact-acme-0003', 'Acme Plumbing (Example)', 'Acme Plumbing (Example)', '', '', '', 'Acme Plumbing (Example)', '[]', '[{"value": "+44 7700 900123", "label": "work"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D61636D652D303030330D0A464E3A41636D6520506C756D62696E6720284578616D706C65290D0A4E3A3B3B3B3B0D0A4F52473A41636D6520506C756D62696E6720284578616D706C65290D0A582D414253686F7741733A434F4D50414E590D0A6974656D312E54454C3A2B34342037373030203930303132330D0A6974656D312E582D41424C6162656C3A776F726B0D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'2B3434203737303020393030313233203434373730303930303132332034373730303930303132332037373030393030313233203730303930303132332030303930303132332030393030313233' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '0bcffba0f5ac233abc48214e5240266d7300ddeedc089fdc705737134535265f', NULL, 'org', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (16, 'eb2f64be-6c41-4053-a030-ccc53b4036d4', 'mac', 'ecab0464-93f6-4448-ae9f-b1195749135f', 'mac://contacts/container-local-0002', 'contact-sam-0004', 'eefd0483689400e1d4d58d5f3045d3b7', 'contact-sam-0004', 'Sam Example', 'Sam Example', 'Sam', 'Example', '', '', '[]', '[{"value": "+44 7700 900103", "label": "mobile"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D73616D2D303030340D0A464E3A53616D204578616D706C650D0A4E3A4578616D706C653B53616D3B3B3B0D0A6974656D312E54454C3A2B34342037373030203930303130330D0A6974656D312E582D41424C6162656C3A5F24213C4D6F62696C653E21245F0D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'2B3434203737303020393030313033203434373730303930303130332034373730303930303130332037373030393030313033203730303930303130332030303930303130332030393030313033' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, 'eefd0483689400e1d4d58d5f3045d3b7b2fa88503d4b8b62f71c966674294d77', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (17, 'f7346ec7-48d9-4b1e-a245-1a9134657f24', 'local', 'owned-book-1', 'owned://contacts/book-1', 'olive.vcf', '', 'olive-owned@example.org', 'Olive Owned', 'Olive Owned', 'Olive', 'Owned', '', '', '[{"value": "olive@example.org", "label": ""}]', '[{"value": "+1 555 0123", "label": "mobile"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A5549443A6F6C6976652D6F776E6564406578616D706C652E6F72670D0A464E3A4F6C697665204F776E65640D0A4E3A4F776E65643B4F6C6976653B3B3B0D0A454D41494C3B545950453D494E5445524E45543A6F6C697665406578616D706C652E6F72670D0A54454C3B545950453D43454C4C3A2B312035353520303132330D0A454E443A56434152440D0A' AS TEXT), 'olive@example.org', CAST(X'2B312035353520303132332031353535303132332035353530313233' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, 'd4b61c72e0ac1391cccc035381e0fc1251270a7ad7abbb827d6cf3fa819aeccb', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (18, 'ea07c916-dbf1-42ed-85f7-5ba49f90a4b7', 'local', 'owned-book-1', 'owned://contacts/book-1', 'pip.vcf', '', 'urn:uuid:pip-owned-1', 'Pip Keepsake', 'Pip Keepsake', 'Pip', 'Keepsake', '', '', '[{"value": "pip@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
UID:urn:uuid:pip-owned-1
FN:Pip Keepsake
N:Keepsake;Pip;;;
EMAIL:pip@example.invalid
END:VCARD
', 'pip@example.invalid', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, 'bdd911258ba03a04732192d4b7251f0aa5376d06c3707419e230072814e631f6', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (19, '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '41381DF4-05AE-408A-9678-65F6FAA88C0D.vcf', '"3-c9ebb423506b4e16"', '41381DF4-05AE-408A-9678-65F6FAA88C0D', 'Wren Written', 'Wren Written', 'Wren', 'Written', 'Wee, Wren', '', '[{"value": "wren@example.org", "label": "home"}]', '[{"value": "+1 555 0177", "label": "mobile"}]', '[]', '--02-29', '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F764361726420656469746F722F2F454E0D0A4E3A5772697474656E3B5772656E3B3B3B0D0A464E3A5772656E205772697474656E0D0A5549443A34313338314446342D303541452D343038412D393637382D3635463646414138384330440D0A54454C3B545950453D43454C4C3A2B312035353520303137370D0A454D41494C3B545950453D484F4D453A7772656E406578616D706C652E6F72670D0A5245563A323032362D31302D31345431373A30373A35335A0D0A4E49434B4E414D453A5765655C2C205772656E0D0A424441593B582D4150504C452D4F4D49542D594541523D313630343A313630342D30322D32390D0A454E443A56434152440D0A' AS TEXT), 'wren@example.org', CAST(X'2B312035353520303137372031353535303137372035353530313737' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 3, 'c9ebb423506b4e16b65d222fe557bb7d9ee7cfcc4d4e475cd313aa8009d351f6', '2026-11-13T17:07:53+00:00', 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (20, 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812.vcf', '"2-731a7a618f813af9"', '', 'Zoë Émile', 'Zoë Émile', 'Zoë', 'Émile', '', '', '[{"value": "zoe@example.org", "label": "home"}]', '[{"value": "+12025550104", "label": "mobile"}, {"value": "+12025550105", "label": "home"}]', '[{"label": "home", "street": "12 Invented Lane, Unit 4", "locality": "Ōtautahi", "region": "", "postal_code": "8000", "country": "Exampleland"}]', '1991-07-02', 'Line one
Line two is a fairly long line of notes that will need a soft break in the quoted printable text, with a comma', 1, 'BEGIN:VCARD
VERSION:3.0
N:Émile;Zoë;;;
FN:Zoë Émile
TEL;TYPE=CELL,PREF:+12025550104
TEL;TYPE=HOME:+12025550105
EMAIL;TYPE=HOME:zoe@example.org
ADR;TYPE=HOME:;;12 Invented Lane\, Unit 4;Ōtautahi;;8000;Exampleland
NOTE:Line one\nLine two is a fairly long line of notes that will need a sof
 t break in the quoted printable text\, with a comma
X-ANDROID-CUSTOM:vnd.android.cursor.item/nickname;Zoëy;1;;;;;;;;;;;;;
BDAY:1991-07-02
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAAAAQIDBAUGBwgJCgsMDQ4P
 EBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRk
 dISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+
 f4CBgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrP/2Q
 ==
END:VCARD
', 'zoe@example.org', CAST(X'2B3132303235353530313034202B313230323535353031303520313230323535353031303420323032353535303130342030323535353031303420323535353031303420353535303130342031323032353535303130352032303235353530313035203032353535303130352032353535303130352035353530313035' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 2, '731a7a618f813af9313a3a01396e77a58441db648bf1f4b7cb2064c9de305ac3', '2026-11-13T17:07:53+00:00', 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (21, '91bdd6a9-ece9-44cc-919f-6d443e3629fd', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '91bdd6a9-ece9-44cc-919f-6d443e3629fd.vcf', '"2-591b6f92f08ba725"', '', 'Pat Placeholder', 'Pat Placeholder', 'Pat', 'Placeholder', '', 'Example Holdings, Invented, Unit', '[]', '[{"value": "+1-202-555-0106", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Placeholder;Pat;;;
FN:Pat Placeholder
TEL;TYPE=WORK,VOICE:+1-202-555-0106
ORG:Example Holdings;Invented\, Unit
END:VCARD
', '', CAST(X'2B312D3230322D3535352D303130362031323032353535303130362032303235353530313036203032353535303130362032353535303130362035353530313036' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 2, '591b6f92f08ba725be09a008be17a905469cabff171bbfe85a703cc2a763d7b2', '2026-11-13T17:07:53+00:00', 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (22, 'b8d96813-de30-4efe-b402-9fadff1543a7', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', 'b8d96813-de30-4efe-b402-9fadff1543a7.vcf', '"3-8808c62faa0bd280"', '3F1C0F0E-0000-4000-8000-00000000A001', 'Ava Fictional', 'Ava Fictional', 'Ava', 'Fictional', 'Avi', 'Example Widgets, Research', '[{"value": "ava@example.com", "label": "work"}, {"value": "ava.home@example.net", "label": "home"}, {"value": "ava.club@example.org", "label": "Chess club"}]', '[{"value": "+1 (555) 010-0100", "label": "mobile"}, {"value": "+44 20 7946 0000", "label": "home"}, {"value": "+1 555 0199", "label": "Gym locker"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Springfield", "region": "", "postal_code": "12345", "country": "Exampleland"}]', '--04-15', 'Met at the invented conference, row two.
Brings biscuits.', 1, 'BEGIN:VCARD
VERSION:3.0
PRODID:-//Apple Inc.//iPhone OS 17.0//EN
N:Fictional;Ava;;;
FN:Ava Fictional
NICKNAME:Avi
ORG:Example Widgets;Research
item1.EMAIL;type=INTERNET;type=pref:ava@example.com
item1.X-ABLabel:_$!<Work>!$_
EMAIL;type=INTERNET;type=HOME:ava.home@example.net
item2.EMAIL;type=INTERNET:ava.club@example.org
item2.X-ABLabel:Chess club
TEL;type=CELL;type=VOICE;type=pref:+1 (555) 010-0100
TEL;type=HOME;type=VOICE:+44 20 7946 0000
item3.TEL:+1 555 0199
item3.X-ABLabel:Gym locker
item4.ADR;type=HOME;type=pref:;;1 Example Street;Springfield;;12345;Exampleland
item4.X-ABADR:us
BDAY;X-APPLE-OMIT-YEAR=1604:1604-04-15
NOTE:Met at the invented conference\, row two.\nBrings biscuits.
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDAsMDQ0MDQ4P
 DxAQEBEREhITExMUFBQVFRUWFhYXFxcYGBgZGRka
UID:3F1C0F0E-0000-4000-8000-00000000A001
X-ABUID:3F1C0F0E-0000-4000-8000-00000000A001:ABPerson
END:VCARD
', 'ava@example.com ava.home@example.net ava.club@example.org', CAST(X'2B31202835353529203031302D30313030202B343420323020373934362030303030202B3120353535203031393920313535353031303031303020353535303130303130302035353031303031303020353031303031303020303130303130302034343230373934363030303020343230373934363030303020323037393436303030302030373934363030303020373934363030303020393436303030302031353535303139392035353530313939' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 3, '8808c62faa0bd280f5277e9d2896e93ead2cf44d71de7abaa0bf7839863fcaa2', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (23, 'c1aea207-7366-4c70-8474-9f455bc6f560', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', 'c1aea207-7366-4c70-8474-9f455bc6f560.vcf', '"1-660dec8182e8e805"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
VERSION:4.0
UID:urn:uuid:00000000-0000-4000-8000-00000000a002
FN:Zoë Exämple
N:Exämple;Zoë;;;
EMAIL;TYPE=work;PREF=1:zoe@example.org
EMAIL;TYPE=home:zoe.home@example.net
TEL;VALUE=uri;TYPE="voice,cell":tel:+44-20-7946-0123
BDAY:19900401
PHOTO:data:image/png;base64,iVBORw0KGgo=
END:VCARD
', 'zoe@example.org zoe.home@example.net', CAST(X'2B34342D32302D373934362D30313233203434323037393436303132332034323037393436303132332032303739343630313233203037393436303132332037393436303132332039343630313233' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (24, 'a4168049-363c-449b-a55e-1b8b5dda9aff', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', 'a4168049-363c-449b-a55e-1b8b5dda9aff.vcf', '"1-602ead1aafe389bc"', '00000000-0000-4000-8000-00000000a003', 'Example Bakery Ltd', '', '', '', '', 'Example Bakery Ltd', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '602ead1aafe389bcabfe067ed80bfa02b7d4a075274b4b3787a6b0aaac17ee54', NULL, 'org', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (25, '689e88a9-2904-4ff9-bc59-596fc7e59d96', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '689e88a9-2904-4ff9-bc59-596fc7e59d96.vcf', '"1-e56104f08ffb7167"', '00000000-0000-4000-8000-00000000a005', 'No name', '', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, 'e56104f08ffb716728f06c038e0e9304bb94f29ad1d0439e6d518a488e7d5231', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (27, 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a.vcf', '"2-65a38df8888f338c"', '00000000-0000-4000-8000-00000000a007', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 2, '65a38df8888f338c4604106e3082f66325da9fd0be48660b86c24175b2fd7fbf', '2026-11-13T17:07:53+00:00', 'individual', '3.0', '6caa48db-081a-406a-8d2f-b12a6483f1f4');
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (28, '2f706c17-7b17-4cba-9dea-7310d29530ef', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '2f706c17-7b17-4cba-9dea-7310d29530ef.vcf', '"1-8cc88a6e32584ccb"', 'group-book-club@example.org', 'Book club', 'Book club', '', 'Book club', '', '', '[]', '[]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '8cc88a6e32584ccbf95df6c18d9ec933e203008b9d96538449eb9ce745835f18', NULL, 'group', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (29, '095b9b51-8227-4a32-81df-dd3d49411893', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '095b9b51-8227-4a32-81df-dd3d49411893.vcf', '"1-9a18e2ccfc36bd19"', 'urn:uuid:group-choir-1', 'Choir (example)', 'Choir (example)', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '9a18e2ccfc36bd19c9fba4bf7bb9fbf5f888091378ba5e9e4fbf4949e81bf66c', NULL, 'group', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (30, '2b67ee70-b3e0-4c86-a609-c42e0eb08e39', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '2b67ee70-b3e0-4c86-a609-c42e0eb08e39.vcf', '"1-2001e615e3fc5dfa"', 'urn:uuid:org-library-1', 'Example Library', 'Example Library', '', '', '', 'Example Library', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '2001e615e3fc5dfa816cba133c4e9eb431044e95095c523081dee3690f34432f', NULL, 'org', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (31, '64c6ae6a-e612-43be-a615-e9e9eac5b19c', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '64c6ae6a-e612-43be-a615-e9e9eac5b19c.vcf', '"1-8839c761111c08e4"', 'kim-invented@example.org', 'Kim Invented', 'Kim Invented', 'Kim', 'Invented', '', '', '[{"value": "kim@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'kim@example.invalid', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '8839c761111c08e401bb7dce974bf74c3a7c89a239f9719a1d379782a283db8e', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (32, '6caa48db-081a-406a-8d2f-b12a6483f1f4', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '6caa48db-081a-406a-8d2f-b12a6483f1f4.vcf', '"1-7e9a392c197a4d60"', '00000000-0000-4000-8000-00000000a006', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '7e9a392c197a4d607c61b3f364a50cb309af8cc93793491b14bd435ee8be33e5', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (33, '3f22cc83-2951-4554-a18f-c36316d64de1', 'local', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'owned://contacts/mydata', '3f22cc83-2951-4554-a18f-c36316d64de1.vcf', '"1-98488030976684c8"', '3F1C0F0E-0000-4000-8000-0000000AE0F1', 'Ava Q Fictional', 'Ava Q Fictional', 'Ava', 'Fictional', '', '', '[{"value": "ava.fictional@example.com", "label": ""}]', '[]', '[]', NULL, 'Invented note.', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F6D61634F532032362E302F2F454E0D0A4E3A46696374696F6E616C3B4176613B513B3B0D0A464E3A41766120512046696374696F6E616C0D0A454D41494C3B747970653D494E5445524E45543A6176612E66696374696F6E616C406578616D706C652E636F6D0D0A4E4F54453A496E76656E746564206E6F74652E0D0A5549443A33463143304630452D303030302D343030302D383030302D3030303030303041453046310D0A454E443A56434152440D0A' AS TEXT), 'ava.fictional@example.com', CAST(X'' AS TEXT), '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', NULL, 1, '98488030976684c81fb9314b080f4516a92d8913b93fa95a42fe0a9c6d407058', NULL, 'individual', '3.0', NULL);
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F764361726420656469746F722F2F454E0D0A4E3A5772697474656E3B5772656E3B3B3B0D0A464E3A5772656E205772697474656E0D0A5549443A34313338314446342D303541452D343038412D393637382D3635463646414138384330440D0A54454C3B545950453D43454C4C3A2B312035353520303137370D0A454D41494C3B545950453D484F4D453A7772656E406578616D706C652E6F72670D0A5245563A323032362D31302D31345431373A30373A35335A0D0A454E443A56434152440D0A' AS TEXT), 'create', 'mycontacts', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 2, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F764361726420656469746F722F2F454E0D0A4E3A5772697474656E3B5772656E3B3B3B0D0A464E3A5772656E205772697474656E0D0A5549443A34313338314446342D303541452D343038412D393637382D3635463646414138384330440D0A54454C3B545950453D43454C4C3A2B312035353520303137370D0A454D41494C3B545950453D484F4D453A7772656E406578616D706C652E6F72670D0A5245563A323032362D31302D31345431373A30373A35335A0D0A4E49434B4E414D453A5765655C2C205772656E0D0A424441593B582D4150504C452D4F4D49542D594541523D313630343A313630342D30322D32390D0A454E443A56434152440D0A' AS TEXT), 'update', 'mycontacts', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 3, NULL, 'delete', 'mydata', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('d3a1a5d9-1f23-4466-a9a1-e55902dc7812', 1, 'BEGIN:VCARD
VERSION:3.0
N:Émile;Zoë;;;
FN:Zoë Émile
TEL;TYPE=CELL,PREF:+12025550104
TEL;TYPE=HOME:+12025550105
EMAIL;TYPE=HOME:zoe@example.org
ADR;TYPE=HOME:;;12 Invented Lane\, Unit 4;Ōtautahi;;8000;Exampleland
NOTE:Line one\nLine two is a fairly long line of notes that will need a sof
 t break in the quoted printable text\, with a comma
X-ANDROID-CUSTOM:vnd.android.cursor.item/nickname;Zoëy;1;;;;;;;;;;;;;
BDAY:1991-07-02
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAAAAQIDBAUGBwgJCgsMDQ4P
 EBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRk
 dISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+
 f4CBgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrP/2Q
 ==
END:VCARD
', 'import', 'import:12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', NULL, '12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('91bdd6a9-ece9-44cc-919f-6d443e3629fd', 1, 'BEGIN:VCARD
VERSION:3.0
N:Placeholder;Pat;;;
FN:Pat Placeholder
TEL;TYPE=WORK,VOICE:+1-202-555-0106
ORG:Example Holdings;Invented\, Unit
END:VCARD
', 'import', 'import:12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', NULL, '12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('d3a1a5d9-1f23-4466-a9a1-e55902dc7812', 2, NULL, 'undo', 'undo-import:mydata', NULL, '12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('91bdd6a9-ece9-44cc-919f-6d443e3629fd', 2, NULL, 'undo', 'undo-import:mydata', NULL, '12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('b8d96813-de30-4efe-b402-9fadff1543a7', 1, 'BEGIN:VCARD
VERSION:3.0
PRODID:-//Apple Inc.//iPhone OS 17.0//EN
N:Fictional;Ava;;;
FN:Ava Fictional
NICKNAME:Avi
ORG:Example Widgets;Research
item1.EMAIL;type=INTERNET;type=pref:ava@example.com
item1.X-ABLabel:_$!<Work>!$_
EMAIL;type=INTERNET;type=HOME:ava.home@example.net
item2.EMAIL;type=INTERNET:ava.club@example.org
item2.X-ABLabel:Chess club
TEL;type=CELL;type=VOICE;type=pref:+1 (555) 010-0100
TEL;type=HOME;type=VOICE:+44 20 7946 0000
item3.TEL:+1 555 0199
item3.X-ABLabel:Gym locker
item4.ADR;type=HOME;type=pref:;;1 Example Street;Springfield;;12345;Exampleland
item4.X-ABADR:us
BDAY;X-APPLE-OMIT-YEAR=1604:1604-04-15
NOTE:Met at the invented conference\, row two.\nBrings biscuits.
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDAsMDQ0MDQ4P
 DxAQEBEREhITExMUFBQVFRUWFhYXFxcYGBgZGRka
UID:3F1C0F0E-0000-4000-8000-00000000A001
X-ABUID:3F1C0F0E-0000-4000-8000-00000000A001:ABPerson
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('c1aea207-7366-4c70-8474-9f455bc6f560', 1, 'BEGIN:VCARD
VERSION:4.0
UID:urn:uuid:00000000-0000-4000-8000-00000000a002
FN:Zoë Exämple
N:Exämple;Zoë;;;
EMAIL;TYPE=work;PREF=1:zoe@example.org
EMAIL;TYPE=home:zoe.home@example.net
TEL;VALUE=uri;TYPE="voice,cell":tel:+44-20-7946-0123
BDAY:19900401
PHOTO:data:image/png;base64,iVBORw0KGgo=
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('a4168049-363c-449b-a55e-1b8b5dda9aff', 1, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('689e88a9-2904-4ff9-bc59-596fc7e59d96', 1, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', 1, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('2f706c17-7b17-4cba-9dea-7310d29530ef', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('095b9b51-8227-4a32-81df-dd3d49411893', 1, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('2b67ee70-b3e0-4c86-a609-c42e0eb08e39', 1, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('64c6ae6a-e612-43be-a615-e9e9eac5b19c', 1, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'import', 'import:80d2e5f3-7686-447f-932b-307fc69f90eb', NULL, '80d2e5f3-7686-447f-932b-307fc69f90eb', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('6caa48db-081a-406a-8d2f-b12a6483f1f4', 1, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'merge', 'mycontacts', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', 2, NULL, 'merge', 'mycontacts', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('3f22cc83-2951-4554-a18f-c36316d64de1', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F6D61634F532032362E302F2F454E0D0A4E3A46696374696F6E616C3B4176613B513B3B0D0A464E3A41766120512046696374696F6E616C0D0A454D41494C3B747970653D494E5445524E45543A6176612E66696374696F6E616C406578616D706C652E636F6D0D0A4E4F54453A496E76656E746564206E6F74652E0D0A5549443A33463143304630452D303030302D343030302D383030302D3030303030303041453046310D0A454E443A56434152440D0A' AS TEXT), 'import', 'import:56d6b225-1982-471f-9da5-db057dc0c62f', NULL, '56d6b225-1982-471f-9da5-db057dc0c62f', '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('b8d96813-de30-4efe-b402-9fadff1543a7', 2, 'BEGIN:VCARD
VERSION:3.0
PRODID:-//Apple Inc.//iPhone OS 17.0//EN
N:Fictional;Ava;;;
FN:Ava Fictional
NICKNAME:Avi B
ORG:Example Widgets;Research
item1.EMAIL;type=INTERNET;type=pref:ava@example.com
item1.X-ABLabel:_$!<Work>!$_
EMAIL;type=INTERNET;type=HOME:ava.home@example.net
item2.EMAIL;type=INTERNET:ava.club@example.org
item2.X-ABLabel:Chess club
TEL;type=CELL;type=VOICE;type=pref:+1 (555) 010-0100
TEL;type=HOME;type=VOICE:+44 20 7946 0000
item3.TEL:+1 555 0199
item3.X-ABLabel:Gym locker
item4.ADR;type=HOME;type=pref:;;1 Example Street;Springfield;;12345;Exampleland
item4.X-ABADR:us
BDAY;X-APPLE-OMIT-YEAR=1604:1604-04-15
NOTE:Met at the invented conference\, row two.\nBrings biscuits.
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDAsMDQ0MDQ4P
 DxAQEBEREhITExMUFBQVFRUWFhYXFxcYGBgZGRka
UID:3F1C0F0E-0000-4000-8000-00000000A001
X-ABUID:3F1C0F0E-0000-4000-8000-00000000A001:ABPerson
REV:2026-10-14T17:07:53Z
END:VCARD
', 'review', 'mycontacts', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('b8d96813-de30-4efe-b402-9fadff1543a7', 3, 'BEGIN:VCARD
VERSION:3.0
PRODID:-//Apple Inc.//iPhone OS 17.0//EN
N:Fictional;Ava;;;
FN:Ava Fictional
NICKNAME:Avi
ORG:Example Widgets;Research
item1.EMAIL;type=INTERNET;type=pref:ava@example.com
item1.X-ABLabel:_$!<Work>!$_
EMAIL;type=INTERNET;type=HOME:ava.home@example.net
item2.EMAIL;type=INTERNET:ava.club@example.org
item2.X-ABLabel:Chess club
TEL;type=CELL;type=VOICE;type=pref:+1 (555) 010-0100
TEL;type=HOME;type=VOICE:+44 20 7946 0000
item3.TEL:+1 555 0199
item3.X-ABLabel:Gym locker
item4.ADR;type=HOME;type=pref:;;1 Example Street;Springfield;;12345;Exampleland
item4.X-ABADR:us
BDAY;X-APPLE-OMIT-YEAR=1604:1604-04-15
NOTE:Met at the invented conference\, row two.\nBrings biscuits.
PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDAsMDQ0MDQ4P
 DxAQEBEREhITExMUFBQVFRUWFhYXFxcYGBgZGRka
UID:3F1C0F0E-0000-4000-8000-00000000A001
X-ABUID:3F1C0F0E-0000-4000-8000-00000000A001:ABPerson
END:VCARD
', 'undo', 'mycontacts', NULL, NULL, '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (1, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', '41381DF4-05AE-408A-9678-65F6FAA88C0D.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (2, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', '41381DF4-05AE-408A-9678-65F6FAA88C0D.vcf', 'modify', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (3, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', '41381DF4-05AE-408A-9678-65F6FAA88C0D.vcf', 'delete', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (4, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812', 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (5, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '91bdd6a9-ece9-44cc-919f-6d443e3629fd', '91bdd6a9-ece9-44cc-919f-6d443e3629fd.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (6, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812', 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812.vcf', 'delete', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (7, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '91bdd6a9-ece9-44cc-919f-6d443e3629fd', '91bdd6a9-ece9-44cc-919f-6d443e3629fd.vcf', 'delete', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (8, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'b8d96813-de30-4efe-b402-9fadff1543a7', 'b8d96813-de30-4efe-b402-9fadff1543a7.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (9, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'c1aea207-7366-4c70-8474-9f455bc6f560', 'c1aea207-7366-4c70-8474-9f455bc6f560.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (10, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'a4168049-363c-449b-a55e-1b8b5dda9aff', 'a4168049-363c-449b-a55e-1b8b5dda9aff.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (11, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '689e88a9-2904-4ff9-bc59-596fc7e59d96', '689e88a9-2904-4ff9-bc59-596fc7e59d96.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (12, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '158fdaf3-8b2e-4b31-9d81-f37d422a3904', '158fdaf3-8b2e-4b31-9d81-f37d422a3904.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (13, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (14, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '2f706c17-7b17-4cba-9dea-7310d29530ef', '2f706c17-7b17-4cba-9dea-7310d29530ef.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (15, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '095b9b51-8227-4a32-81df-dd3d49411893', '095b9b51-8227-4a32-81df-dd3d49411893.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (16, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '2b67ee70-b3e0-4c86-a609-c42e0eb08e39', '2b67ee70-b3e0-4c86-a609-c42e0eb08e39.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (17, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '64c6ae6a-e612-43be-a615-e9e9eac5b19c', '64c6ae6a-e612-43be-a615-e9e9eac5b19c.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (18, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '6caa48db-081a-406a-8d2f-b12a6483f1f4', '6caa48db-081a-406a-8d2f-b12a6483f1f4.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (19, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '158fdaf3-8b2e-4b31-9d81-f37d422a3904', '158fdaf3-8b2e-4b31-9d81-f37d422a3904.vcf', 'delete', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (20, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a.vcf', 'delete', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (21, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '3f22cc83-2951-4554-a18f-c36316d64de1', '3f22cc83-2951-4554-a18f-c36316d64de1.vcf', 'add', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (22, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'b8d96813-de30-4efe-b402-9fadff1543a7', 'b8d96813-de30-4efe-b402-9fadff1543a7.vcf', 'modify', '2026-10-14T17:07:53+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (23, '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', 'b8d96813-de30-4efe-b402-9fadff1543a7', 'b8d96813-de30-4efe-b402-9fadff1543a7.vcf', 'modify', '2026-10-14T17:07:53+00:00');
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('2ccc6ceb-e07a-42ae-8cd2-52dedeb1f1d5', '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 'create', 'mycontacts', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('38eeb879-84b8-4ab6-b792-0e2b621bdbbb', '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 'update', 'mycontacts', 2, 1, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('4bea0eee-faf3-4616-a78d-3ec72e3772ff', '0ddff73a-73f0-48ab-a8c8-a8dc79a41acf', 'delete', 'mydata', 3, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('36367f7e-560d-4459-a469-a91398d99e1c', 'd3a1a5d9-1f23-4466-a9a1-e55902dc7812', 'create', 'mycontacts', 1, NULL, '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 'mydata', 2);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('e7fa519e-c2eb-42dd-b62d-3661b1136be6', '91bdd6a9-ece9-44cc-919f-6d443e3629fd', 'create', 'mycontacts', 1, NULL, '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 'mydata', 2);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('8bcc2b4a-1919-4544-a5bc-172cff7656aa', 'b8d96813-de30-4efe-b402-9fadff1543a7', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('35a4b606-882d-4a60-bd90-76e31710cd3c', 'c1aea207-7366-4c70-8474-9f455bc6f560', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('17ab9c7c-91cb-41ff-97e1-1d78e50ad044', 'a4168049-363c-449b-a55e-1b8b5dda9aff', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('1014b88f-2bb5-43f7-bb62-e42269bdf0e8', '689e88a9-2904-4ff9-bc59-596fc7e59d96', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('832eca14-1eec-4935-bcd7-45806e6aba7c', '158fdaf3-8b2e-4b31-9d81-f37d422a3904', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('9c4ba42f-9880-4449-927a-6dec4beaebd7', 'c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('77488186-4698-4067-a5ff-11ed9d2088bc', '2b67ee70-b3e0-4c86-a609-c42e0eb08e39', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('b66a7c9f-77f2-4ca8-ab13-bece50c9d8eb', '64c6ae6a-e612-43be-a615-e9e9eac5b19c', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('844d38f7-13a9-4c77-8ec3-5faef50fde2a', '3f22cc83-2951-4554-a18f-c36316d64de1', 'create', 'mydata', 1, NULL, '2026-10-14T17:07:53+00:00', NULL, NULL, NULL);
INSERT INTO "imports" (id, source, label, started_at, finished_at, counts, status, actor, source_account, address_book_id, undone_at, undone_by) VALUES ('12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', 'file', 'samsung.vcf', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '{"cards": 2, "contacts": 2, "groups": 0, "skipped": 0, "new": 2, "duplicates": 0, "in_file": 0, "unchanged": 0, "updates": 0, "conflicts": 0, "deleted": 0, "suggestions": 1, "followed_matches": 0, "missing": 0, "to_import": 2, "to_update": 0, "to_link": 0, "created": 2, "groups_created": 0, "updated": 0, "linked": 0, "not_written": 0, "hidden": 0, "undo": {"removed": 2, "groups_removed": 0, "reverted": 0, "unlinked": 0, "unhidden": 0, "kept": 0, "gone": 0}}', 'undone', 'mycontacts', '', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', '2026-10-14T17:07:53+00:00', 'mydata');
INSERT INTO "imports" (id, source, label, started_at, finished_at, counts, status, actor, source_account, address_book_id, undone_at, undone_by) VALUES ('80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', 'iCloud account', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '{"cards": 10, "contacts": 8, "groups": 2, "skipped": 0, "new": 10, "duplicates": 0, "in_file": 0, "unchanged": 0, "updates": 0, "conflicts": 0, "deleted": 0, "suggestions": 1, "followed_matches": 0, "missing": 0, "to_import": 10, "to_update": 0, "to_link": 0, "created": 8, "groups_created": 2, "updated": 0, "linked": 0, "not_written": 0, "hidden": 0}', 'committed', 'mydata', 'acc-1', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', NULL, NULL);
INSERT INTO "imports" (id, source, label, started_at, finished_at, counts, status, actor, source_account, address_book_id, undone_at, undone_by) VALUES ('56d6b225-1982-471f-9da5-db057dc0c62f', 'file', 'Contacts.vcf', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', '{"cards": 1, "contacts": 1, "groups": 0, "skipped": 0, "new": 1, "duplicates": 0, "in_file": 0, "unchanged": 0, "updates": 0, "conflicts": 0, "deleted": 0, "suggestions": 0, "followed_matches": 1, "missing": 0, "to_import": 1, "to_update": 0, "to_link": 0, "created": 1, "groups_created": 0, "updated": 0, "linked": 0, "not_written": 0, "hidden": 1}', 'committed', 'mydata', '', '99d0e801-6812-4ae8-9aa5-73b0019d1bf7', NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('d3a1a5d9-1f23-4466-a9a1-e55902dc7812', '12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', 'file', 'sha256:a1e9dc08ab79d9c8bc4a5db5f58886f980a44fa717a264423c756efc8b9f9dfa', '5b02a6b879529e7c94d63561c28753ee5d51bfa834e7eaf6db287b5ffb2dcff0', 'BEGIN:VCARD
VERSION:2.1
N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=89mile;Zo=C3=AB;;;
FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Zo=C3=AB =C3=89mile
TEL;CELL;PREF:+12025550104
TEL;HOME:+12025550105
EMAIL;HOME:zoe@example.org
ADR;HOME;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:;;12 Invented Lane, Unit 4;=C5=8Ctautahi;;8000;Exampleland
NOTE;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Line one=0D=0ALine two is a fairly long line of notes that will need a soft break in the =
quoted printable text, with a comma
X-ANDROID-CUSTOM;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:vnd.android.cursor.item/nickname;Zo=C3=AB=
y;1;;;;;;;;;;;;;
BDAY:1991-07-02
PHOTO;ENCODING=BASE64;JPEG:/9j/4AAQSkZJRgABAQAAAQABAAAAAQIDBAUGBwgJCgsMDQ4PEB
 ESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRkdISU
 pLTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+f4CBgo
 OEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrP/2Q==

END:VCARD
', 1, '', 'create', NULL, '2026-10-14T17:07:53+00:00', NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('91bdd6a9-ece9-44cc-919f-6d443e3629fd', '12cd8c5f-8a7d-42ef-8f42-7467b1fb6979', 'file', 'sha256:eabd7b2a17d667d18ac934322ff4e3604137762737d4062396113bf290ad7d90', '09981a5f1cb53451a63286c3631390e1e26aec4b3ed886515497509024e8fb19', 'BEGIN:VCARD
VERSION:2.1
N:Placeholder;Pat;;;
FN:Pat Placeholder
TEL;WORK;VOICE:+1-202-555-0106
ORG:Example Holdings;Invented, Unit
END:VCARD
', 1, '', 'create', NULL, '2026-10-14T17:07:53+00:00', NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('b8d96813-de30-4efe-b402-9fadff1543a7', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', '3F1C0F0E-0000-4000-8000-00000000A001', '8808c62faa0bd280f5277e9d2896e93ead2cf44d71de7abaa0bf7839863fcaa2', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, 'a1eeef6b5b913cdb70c186c31c7aaf3b0e07c970cc37ad92c9c42c221f125d5a');
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('c1aea207-7366-4c70-8474-9f455bc6f560', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', 'urn:uuid:00000000-0000-4000-8000-00000000a002', '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('a4168049-363c-449b-a55e-1b8b5dda9aff', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', '00000000-0000-4000-8000-00000000a003', '602ead1aafe389bcabfe067ed80bfa02b7d4a075274b4b3787a6b0aaac17ee54', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('689e88a9-2904-4ff9-bc59-596fc7e59d96', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', '00000000-0000-4000-8000-00000000a005', 'e56104f08ffb716728f06c038e0e9304bb94f29ad1d0439e6d518a488e7d5231', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('158fdaf3-8b2e-4b31-9d81-f37d422a3904', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', '00000000-0000-4000-8000-00000000a006', '7e9a392c197a4d607c61b3f364a50cb309af8cc93793491b14bd435ee8be33e5', NULL, 1, 'acc-1', 'create', NULL, NULL, '6caa48db-081a-406a-8d2f-b12a6483f1f4', NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('c70c2cdc-f06a-463a-b1c6-3c6c14c1298a', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', '00000000-0000-4000-8000-00000000a007', '65a38df8888f338c4604106e3082f66325da9fd0be48660b86c24175b2fd7fbf', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('2f706c17-7b17-4cba-9dea-7310d29530ef', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', 'group-book-club@example.org', '8cc88a6e32584ccbf95df6c18d9ec933e203008b9d96538449eb9ce745835f18', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('095b9b51-8227-4a32-81df-dd3d49411893', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', 'urn:uuid:group-choir-1', '9a18e2ccfc36bd19c9fba4bf7bb9fbf5f888091378ba5e9e4fbf4949e81bf66c', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('2b67ee70-b3e0-4c86-a609-c42e0eb08e39', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', 'urn:uuid:org-library-1', '2001e615e3fc5dfa816cba133c4e9eb431044e95095c523081dee3690f34432f', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('64c6ae6a-e612-43be-a615-e9e9eac5b19c', '80d2e5f3-7686-447f-932b-307fc69f90eb', 'icloud', 'kim-invented@example.org', '8839c761111c08e401bb7dce974bf74c3a7c89a239f9719a1d379782a283db8e', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by, reviewed_hash) VALUES ('3f22cc83-2951-4554-a18f-c36316d64de1', '56d6b225-1982-471f-9da5-db057dc0c62f', 'file', '3F1C0F0E-0000-4000-8000-0000000AE0F1', '98488030976684c81fb9314b080f4516a92d8913b93fa95a42fe0a9c6d407058', NULL, 1, '', 'create', NULL, NULL, NULL, NULL);
INSERT INTO "merges" (id, merged_id, merged_rev, originals, links, actor, at, undone_at, undone_by) VALUES ('1039c401-f580-4ab8-a297-77584d81a497', '6caa48db-081a-406a-8d2f-b12a6483f1f4', 1, '[{"id": "158fdaf3-8b2e-4b31-9d81-f37d422a3904", "rev": 2}, {"id": "c70c2cdc-f06a-463a-b1c6-3c6c14c1298a", "rev": 2}]', '{}', 'mycontacts', '2026-10-14T17:07:53+00:00', NULL, NULL);
INSERT INTO "shadows" (object_id, import_id, source_account, source_uid, source_hash, held_by, undone_at, reviewed_hash) VALUES ('3f22cc83-2951-4554-a18f-c36316d64de1', '56d6b225-1982-471f-9da5-db057dc0c62f', 'mac', 'contact-ava-0001', '650fe18de1d16a3867cbba7e859e00a0e9126d35333ed37771e9f9584f9ec1a1', NULL, NULL, NULL);
INSERT INTO "decisions" (id, kind, object_id, other_id, data, actor, at, undone_at, undone_by) VALUES ('338d9812-b345-4aa4-a5a8-78d50f708445', 'save_changes', 'b8d96813-de30-4efe-b402-9fadff1543a7', NULL, '{"rev": 2, "prior_rev": 1, "links": [{"table": "origins", "rowid": 3, "prior": null, "now": "a1eeef6b5b913cdb70c186c31c7aaf3b0e07c970cc37ad92c9c42c221f125d5a"}]}', 'mycontacts', '2026-10-14T17:07:53+00:00', '2026-10-14T17:07:53+00:00', 'mycontacts');
INSERT INTO "decisions" (id, kind, object_id, other_id, data, actor, at, undone_at, undone_by) VALUES ('39af4697-cbf8-4a49-b00e-835edbd73254', 'keep_mine', 'b8d96813-de30-4efe-b402-9fadff1543a7', NULL, '{"links": [{"table": "origins", "rowid": 3, "prior": null, "now": "a1eeef6b5b913cdb70c186c31c7aaf3b0e07c970cc37ad92c9c42c221f125d5a"}]}', 'mycontacts', '2026-10-14T17:07:53+00:00', NULL, NULL);
