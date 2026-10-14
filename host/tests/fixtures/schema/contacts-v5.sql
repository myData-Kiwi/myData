-- Synthetic contacts.sqlite at schema version 5, written by make_dump.py. Invented data only.
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (1, '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'acc-1', 'https://contacts.example.com/1/carddavhome/card/', 'Card', NULL, 't1', NULL, '{}', '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (2, '133af02c-8cc3-4397-87fa-cbbed1636db3', 'acc-2', 'https://contacts.example.com/1/carddavhome/work/', 'Work', NULL, 't1', NULL, '{"/2/card/zoe.vcf": "\"1\""}', '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (3, '70ff7149-7a56-467e-9277-cce472601797', 'mac', 'mac://contacts/container-icloud-0001', 'container-icloud-0001', NULL, NULL, NULL, '{"contact-ava-0001": "650fe18de1d16a3867cbba7e859e00a0", "contact-sam-0002": "1fb626b2c74fe2a59863c44f670d4704"}', '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (4, '8268df16-d7ab-4c73-928a-45b66d1fb514', 'mac', 'mac://contacts/container-local-0002', 'container-local-0002', NULL, NULL, NULL, '{"contact-acme-0003": "0bcffba0f5ac233abc48214e5240266d", "contact-sam-0004": "eefd0483689400e1d4d58d5f3045d3b7"}', '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 'followed');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (5, 'owned-book-1', 'local', 'owned://contacts/book-1', 'Kept (owned)', NULL, NULL, NULL, '{}', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 'owned');
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at, mode) VALUES (6, '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'local', 'owned://contacts/mydata', 'myData', NULL, NULL, NULL, '{}', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 'owned');
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (1, 'd7f2414b-eb87-48fd-91e9-81bc893f64ff', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/ava-fictional.vcf', '"1"', '3F1C0F0E-0000-4000-8000-00000000A001', 'Ava Fictional', 'Ava Fictional', 'Ava', 'Fictional', 'Avi', 'Example Widgets, Research', '[{"value": "ava@example.com", "label": "work"}, {"value": "ava.home@example.net", "label": "home"}, {"value": "ava.club@example.org", "label": "Chess club"}]', '[{"value": "+1 (555) 010-0100", "label": "mobile"}, {"value": "+44 20 7946 0000", "label": "home"}, {"value": "+1 555 0199", "label": "Gym locker"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Springfield", "region": "", "postal_code": "12345", "country": "Exampleland"}]', '--04-15', 'Met at the invented conference, row two.
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
', 'ava@example.com ava.home@example.net ava.club@example.org', CAST(X'2B31202835353529203031302D30313030202B343420323020373934362030303030202B3120353535203031393920313535353031303031303020353535303130303130302035353031303031303020353031303031303020303130303130302034343230373934363030303020343230373934363030303020323037393436303030302030373934363030303020373934363030303020393436303030302031353535303139392035353530313939' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '8808c62faa0bd280f5277e9d2896e93ead2cf44d71de7abaa0bf7839863fcaa2', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (2, '12242c95-68f2-4f95-bf75-d2d91ef413b8', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/zoe-example-v4.vcf', '"1"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
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
', 'zoe@example.org zoe.home@example.net', CAST(X'2B34342D32302D373934362D30313233203434323037393436303132332034323037393436303132332032303739343630313233203037393436303132332037393436303132332039343630313233' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (3, '433070e3-198c-45b9-a616-318f22b9f72d', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/org-only.vcf', '"1"', '00000000-0000-4000-8000-00000000a003', 'Example Bakery Ltd', '', '', '', '', 'Example Bakery Ltd', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '602ead1aafe389bcabfe067ed80bfa02b7d4a075274b4b3787a6b0aaac17ee54', NULL, 'org', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (4, '159b58be-48e7-478c-baa7-1d6bae396859', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/phone-only.vcf', '"1"', '00000000-0000-4000-8000-00000000a004', '+1 555 0177', '', '', '', '', '', '[]', '[{"value": "+1 555 0177", "label": "mobile"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
TEL;type=CELL:+1 555 0177
UID:00000000-0000-4000-8000-00000000a004
END:VCARD
', '', CAST(X'2B312035353520303137372031353535303137372035353530313737' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', 1, '80c9e5e4a328298b6448a8270c22c2ca9ebc2bd2f72ae4e7e51bb5cf23867977', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (5, '362b4c28-2cab-483b-afc7-ab39c5ce5ed0', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/empty.vcf', '"1"', '00000000-0000-4000-8000-00000000a005', 'No name', '', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, 'e56104f08ffb716728f06c038e0e9304bb94f29ad1d0439e6d518a488e7d5231', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (6, '06a89f7f-645d-4c19-95b3-71a4ba2525ac', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/sam-sample-1.vcf', '"1"', '00000000-0000-4000-8000-00000000a006', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '7e9a392c197a4d607c61b3f364a50cb309af8cc93793491b14bd435ee8be33e5', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (7, '8b3c0c12-ef88-48a6-8fa2-71efcc71abfe', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/sam-sample-2.vcf', '"1"', '00000000-0000-4000-8000-00000000a007', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '65a38df8888f338c4604106e3082f66325da9fd0be48660b86c24175b2fd7fbf', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (8, 'f215e751-094c-46d6-a709-b51532c21519', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/group-3.vcf', '"x0"', 'group-book-club@example.org', 'Book club', 'Book club', '', 'Book club', '', '', '[]', '[]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '8cc88a6e32584ccbf95df6c18d9ec933e203008b9d96538449eb9ce745835f18', NULL, 'group', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (9, 'dc846c78-ac0a-49b7-8157-475cf13ca789', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/group-4.vcf', '"x1"', 'urn:uuid:group-choir-1', 'Choir (example)', 'Choir (example)', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '9a18e2ccfc36bd19c9fba4bf7bb9fbf5f888091378ba5e9e4fbf4949e81bf66c', NULL, 'group', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (10, '64b4f423-d813-41a5-8546-cd72d1fc8de9', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/org-4.vcf', '"x2"', 'urn:uuid:org-library-1', 'Example Library', 'Example Library', '', '', '', 'Example Library', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '2001e615e3fc5dfa816cba133c4e9eb431044e95095c523081dee3690f34432f', NULL, 'org', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (11, '02b4c50b-7418-48eb-aed7-8c55a8e16f41', 'acc-1', '0db2b4ac-cf8d-4fe0-83e6-d2e4bf6f879c', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/kim.vcf', '"x3"', 'kim-invented@example.org', 'Kim Invented', 'Kim Invented', 'Kim', 'Invented', '', '', '[{"value": "kim@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'kim@example.invalid', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '8839c761111c08e401bb7dce974bf74c3a7c89a239f9719a1d379782a283db8e', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (12, '326fdc0f-3ba6-4dfd-87c7-2d0d5f18c4cf', 'acc-2', '133af02c-8cc3-4397-87fa-cbbed1636db3', 'https://contacts.example.com/1/carddavhome/work/', '/2/card/zoe.vcf', '"1"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
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
', 'zoe@example.org zoe.home@example.net', CAST(X'2B34342D32302D373934362D30313233203434323037393436303132332034323037393436303132332032303739343630313233203037393436303132332037393436303132332039343630313233' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (13, '34138636-e571-4d7a-b147-0541e828db01', 'mac', '70ff7149-7a56-467e-9277-cce472601797', 'mac://contacts/container-icloud-0001', 'contact-ava-0001', '650fe18de1d16a3867cbba7e859e00a0', 'contact-ava-0001', 'Ava Q Fictional', 'Ava Q Fictional', 'Ava', 'Fictional', 'Avi', 'Example Labs', '[{"value": "ava.fictional@example.com", "label": "home"}, {"value": "ava@work.example.net", "label": "work"}]', '[{"value": "+1 202 555 0101", "label": "mobile"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Testville", "region": "", "postal_code": "00000", "country": "Exampleland"}]', '1990-04-12', '', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D6176612D303030310D0A464E3A41766120512046696374696F6E616C0D0A4E3A46696374696F6E616C3B4176613B513B3B0D0A4E49434B4E414D453A4176690D0A4F52473A4578616D706C65204C6162730D0A5449544C453A496E76656E746F720D0A6974656D312E454D41494C3B545950453D494E5445524E45543A6176612E66696374696F6E616C406578616D706C652E636F6D0D0A6974656D312E582D41424C6162656C3A5F24213C486F6D653E21245F0D0A6974656D322E454D41494C3B545950453D494E5445524E45543A61766140776F726B2E6578616D706C652E6E65740D0A6974656D322E582D41424C6162656C3A5F24213C576F726B3E21245F0D0A6974656D332E54454C3A2B31203230322035353520303130310D0A6974656D332E582D41424C6162656C3A5F24213C4D6F62696C653E21245F0D0A6974656D342E4144523A3B3B31204578616D706C65205374726565743B5465737476696C6C653B3B30303030303B4578616D706C656C616E640D0A6974656D342E582D41424C6162656C3A5F24213C486F6D653E21245F0D0A424441593A313939302D30342D31320D0A6974656D352E55524C3A68747470733A2F2F7777772E6578616D706C652E6F72672F6176610D0A6974656D352E582D41424C6162656C3A686F6D65706167650D0A50484F544F3B454E434F44494E473D623B545950453D4A5045473A2F396A2F34476C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F0D0A20623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D0D0A2056756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A350D0A206447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C662F5A0D0A454E443A56434152440D0A' AS TEXT), 'ava.fictional@example.com ava@work.example.net', CAST(X'2B31203230322035353520303130312031323032353535303130312032303235353530313031203032353535303130312032353535303130312035353530313031' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '650fe18de1d16a3867cbba7e859e00a0e9126d35333ed37771e9f9584f9ec1a1', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (14, '6f89a089-be66-4fa2-9af6-f3e33da6eb15', 'mac', '70ff7149-7a56-467e-9277-cce472601797', 'mac://contacts/container-icloud-0001', 'contact-sam-0002', '1fb626b2c74fe2a59863c44f670d4704', 'contact-sam-0002', 'Sam Example', 'Sam Example', 'Sam', 'Example', '', '', '[{"value": "sam.example@example.com", "label": ""}]', '[]', '[]', '--07-04', '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D73616D2D303030320D0A464E3A53616D204578616D706C650D0A4E3A4578616D706C653B53616D3B3B3B0D0A6974656D312E454D41494C3B545950453D494E5445524E45543A73616D2E6578616D706C65406578616D706C652E636F6D0D0A424441593A2D2D30372D30340D0A454E443A56434152440D0A' AS TEXT), 'sam.example@example.com', CAST(X'' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '1fb626b2c74fe2a59863c44f670d47041a06bac5bbf6d0ec761619017fd6247a', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (15, '3356a89e-ed72-4c82-a0cd-c624555a526a', 'mac', '8268df16-d7ab-4c73-928a-45b66d1fb514', 'mac://contacts/container-local-0002', 'contact-acme-0003', '0bcffba0f5ac233abc48214e5240266d', 'contact-acme-0003', 'Acme Plumbing (Example)', 'Acme Plumbing (Example)', '', '', '', 'Acme Plumbing (Example)', '[]', '[{"value": "+44 7700 900123", "label": "work"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D61636D652D303030330D0A464E3A41636D6520506C756D62696E6720284578616D706C65290D0A4E3A3B3B3B3B0D0A4F52473A41636D6520506C756D62696E6720284578616D706C65290D0A582D414253686F7741733A434F4D50414E590D0A6974656D312E54454C3A2B34342037373030203930303132330D0A6974656D312E582D41424C6162656C3A776F726B0D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'2B3434203737303020393030313233203434373730303930303132332034373730303930303132332037373030393030313233203730303930303132332030303930303132332030393030313233' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, '0bcffba0f5ac233abc48214e5240266d7300ddeedc089fdc705737134535265f', NULL, 'org', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (16, '52218ae7-d86b-4067-a9ae-ee9a79c1358c', 'mac', '8268df16-d7ab-4c73-928a-45b66d1fb514', 'mac://contacts/container-local-0002', 'contact-sam-0004', 'eefd0483689400e1d4d58d5f3045d3b7', 'contact-sam-0004', 'Sam Example', 'Sam Example', 'Sam', 'Example', '', '', '[]', '[{"value": "+44 7700 900103", "label": "mobile"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D73616D2D303030340D0A464E3A53616D204578616D706C650D0A4E3A4578616D706C653B53616D3B3B3B0D0A6974656D312E54454C3A2B34342037373030203930303130330D0A6974656D312E582D41424C6162656C3A5F24213C4D6F62696C653E21245F0D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'2B3434203737303020393030313033203434373730303930303130332034373730303930303130332037373030393030313033203730303930303130332030303930303130332030393030313033' AS TEXT), '2026-10-14T15:50:33+00:00', '2026-10-14T15:50:33+00:00', NULL, 1, 'eefd0483689400e1d4d58d5f3045d3b7b2fa88503d4b8b62f71c966674294d77', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (17, 'be89cdf0-b2c6-4e77-aff5-c2892833d2db', 'local', 'owned-book-1', 'owned://contacts/book-1', 'olive.vcf', '', 'olive-owned@example.org', 'Olive Owned', 'Olive Owned', 'Olive', 'Owned', '', '', '[{"value": "olive@example.org", "label": ""}]', '[{"value": "+1 555 0123", "label": "mobile"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A5549443A6F6C6976652D6F776E6564406578616D706C652E6F72670D0A464E3A4F6C697665204F776E65640D0A4E3A4F776E65643B4F6C6976653B3B3B0D0A454D41494C3B545950453D494E5445524E45543A6F6C697665406578616D706C652E6F72670D0A54454C3B545950453D43454C4C3A2B312035353520303132330D0A454E443A56434152440D0A' AS TEXT), 'olive@example.org', CAST(X'2B312035353520303132332031353535303132332035353530313233' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, 'd4b61c72e0ac1391cccc035381e0fc1251270a7ad7abbb827d6cf3fa819aeccb', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (18, 'c0a49539-1ba6-477b-9b23-7faad0f26970', 'local', 'owned-book-1', 'owned://contacts/book-1', 'pip.vcf', '', 'urn:uuid:pip-owned-1', 'Pip Keepsake', 'Pip Keepsake', 'Pip', 'Keepsake', '', '', '[{"value": "pip@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
UID:urn:uuid:pip-owned-1
FN:Pip Keepsake
N:Keepsake;Pip;;;
EMAIL:pip@example.invalid
END:VCARD
', 'pip@example.invalid', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, 'bdd911258ba03a04732192d4b7251f0aa5376d06c3707419e230072814e631f6', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (19, '054552df-9b70-42e1-b70a-0242d63787f9', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '4D2C82B0-360E-4215-89A5-0A1449F6A665.vcf', '"3-03a0f5e51fdd4692"', '4D2C82B0-360E-4215-89A5-0A1449F6A665', 'Wren Written', 'Wren Written', 'Wren', 'Written', 'Wee, Wren', '', '[{"value": "wren@example.org", "label": "home"}]', '[{"value": "+1 555 0177", "label": "mobile"}]', '[]', '--02-29', '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F764361726420656469746F722F2F454E0D0A4E3A5772697474656E3B5772656E3B3B3B0D0A464E3A5772656E205772697474656E0D0A5549443A34443243383242302D333630452D343231352D383941352D3041313434394636413636350D0A54454C3B545950453D43454C4C3A2B312035353520303137370D0A454D41494C3B545950453D484F4D453A7772656E406578616D706C652E6F72670D0A5245563A323032362D31302D31345431353A35303A33345A0D0A4E49434B4E414D453A5765655C2C205772656E0D0A424441593B582D4150504C452D4F4D49542D594541523D313630343A313630342D30322D32390D0A454E443A56434152440D0A' AS TEXT), 'wren@example.org', CAST(X'2B312035353520303137372031353535303137372035353530313737' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', 3, '03a0f5e51fdd4692114dde0bb69bf6c4dcb3a9b14e784f109fd3d9d171e63fea', '2026-11-13T15:50:34+00:00', 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (20, 'a1ea97f3-9886-465f-b39f-cf553df9d287', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', 'a1ea97f3-9886-465f-b39f-cf553df9d287.vcf', '"2-731a7a618f813af9"', '', 'Zoë Émile', 'Zoë Émile', 'Zoë', 'Émile', '', '', '[{"value": "zoe@example.org", "label": "home"}]', '[{"value": "+12025550104", "label": "mobile"}, {"value": "+12025550105", "label": "home"}]', '[{"label": "home", "street": "12 Invented Lane, Unit 4", "locality": "Ōtautahi", "region": "", "postal_code": "8000", "country": "Exampleland"}]', '1991-07-02', 'Line one
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
', 'zoe@example.org', CAST(X'2B3132303235353530313034202B313230323535353031303520313230323535353031303420323032353535303130342030323535353031303420323535353031303420353535303130342031323032353535303130352032303235353530313035203032353535303130352032353535303130352035353530313035' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', 2, '731a7a618f813af9313a3a01396e77a58441db648bf1f4b7cb2064c9de305ac3', '2026-11-13T15:50:34+00:00', 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (21, '5524de27-8975-4b97-8445-c36bd2c8b791', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '5524de27-8975-4b97-8445-c36bd2c8b791.vcf', '"2-591b6f92f08ba725"', '', 'Pat Placeholder', 'Pat Placeholder', 'Pat', 'Placeholder', '', 'Example Holdings, Invented, Unit', '[]', '[{"value": "+1-202-555-0106", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Placeholder;Pat;;;
FN:Pat Placeholder
TEL;TYPE=WORK,VOICE:+1-202-555-0106
ORG:Example Holdings;Invented\, Unit
END:VCARD
', '', CAST(X'2B312D3230322D3535352D303130362031323032353535303130362032303235353530313036203032353535303130362032353535303130362035353530313036' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', 2, '591b6f92f08ba725be09a008be17a905469cabff171bbfe85a703cc2a763d7b2', '2026-11-13T15:50:34+00:00', 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (22, '44409042-af20-4377-a010-b77bb1d0a50c', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '44409042-af20-4377-a010-b77bb1d0a50c.vcf', '"1-8808c62faa0bd280"', '3F1C0F0E-0000-4000-8000-00000000A001', 'Ava Fictional', 'Ava Fictional', 'Ava', 'Fictional', 'Avi', 'Example Widgets, Research', '[{"value": "ava@example.com", "label": "work"}, {"value": "ava.home@example.net", "label": "home"}, {"value": "ava.club@example.org", "label": "Chess club"}]', '[{"value": "+1 (555) 010-0100", "label": "mobile"}, {"value": "+44 20 7946 0000", "label": "home"}, {"value": "+1 555 0199", "label": "Gym locker"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Springfield", "region": "", "postal_code": "12345", "country": "Exampleland"}]', '--04-15', 'Met at the invented conference, row two.
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
', 'ava@example.com ava.home@example.net ava.club@example.org', CAST(X'2B31202835353529203031302D30313030202B343420323020373934362030303030202B3120353535203031393920313535353031303031303020353535303130303130302035353031303031303020353031303031303020303130303130302034343230373934363030303020343230373934363030303020323037393436303030302030373934363030303020373934363030303020393436303030302031353535303139392035353530313939' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '8808c62faa0bd280f5277e9d2896e93ead2cf44d71de7abaa0bf7839863fcaa2', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (23, '26a33067-8cfd-4e10-a170-c180c6b5a0da', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '26a33067-8cfd-4e10-a170-c180c6b5a0da.vcf', '"1-660dec8182e8e805"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
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
', 'zoe@example.org zoe.home@example.net', CAST(X'2B34342D32302D373934362D30313233203434323037393436303132332034323037393436303132332032303739343630313233203037393436303132332037393436303132332039343630313233' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 'individual', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (24, '64d5657b-9f82-496d-96a6-c381932333df', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '64d5657b-9f82-496d-96a6-c381932333df.vcf', '"1-602ead1aafe389bc"', '00000000-0000-4000-8000-00000000a003', 'Example Bakery Ltd', '', '', '', '', 'Example Bakery Ltd', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '602ead1aafe389bcabfe067ed80bfa02b7d4a075274b4b3787a6b0aaac17ee54', NULL, 'org', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (25, '7563283d-c73c-4065-9d37-29714ab62b75', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '7563283d-c73c-4065-9d37-29714ab62b75.vcf', '"1-e56104f08ffb7167"', '00000000-0000-4000-8000-00000000a005', 'No name', '', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, 'e56104f08ffb716728f06c038e0e9304bb94f29ad1d0439e6d518a488e7d5231', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (27, 'd2e4786e-6ea3-4ab2-9908-3066e8b75401', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', 'd2e4786e-6ea3-4ab2-9908-3066e8b75401.vcf', '"2-65a38df8888f338c"', '00000000-0000-4000-8000-00000000a007', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', 2, '65a38df8888f338c4604106e3082f66325da9fd0be48660b86c24175b2fd7fbf', '2026-11-13T15:50:34+00:00', 'individual', '3.0', '5e5d53ae-f33f-4e36-821f-8ff520d1bb02');
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (28, '1876c35f-8f2e-4af0-a09a-a6bfbddc3ce8', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '1876c35f-8f2e-4af0-a09a-a6bfbddc3ce8.vcf', '"1-8cc88a6e32584ccb"', 'group-book-club@example.org', 'Book club', 'Book club', '', 'Book club', '', '', '[]', '[]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), '', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '8cc88a6e32584ccbf95df6c18d9ec933e203008b9d96538449eb9ce745835f18', NULL, 'group', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (29, '26758707-eebe-44fc-9c82-63ac1a0cdb6b', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '26758707-eebe-44fc-9c82-63ac1a0cdb6b.vcf', '"1-9a18e2ccfc36bd19"', 'urn:uuid:group-choir-1', 'Choir (example)', 'Choir (example)', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', '', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '9a18e2ccfc36bd19c9fba4bf7bb9fbf5f888091378ba5e9e4fbf4949e81bf66c', NULL, 'group', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (30, '4e05009a-b4aa-4248-8441-7f947399a32f', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '4e05009a-b4aa-4248-8441-7f947399a32f.vcf', '"1-2001e615e3fc5dfa"', 'urn:uuid:org-library-1', 'Example Library', 'Example Library', '', '', '', 'Example Library', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', '', CAST(X'2B312035353520303134322031353535303134322035353530313432' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '2001e615e3fc5dfa816cba133c4e9eb431044e95095c523081dee3690f34432f', NULL, 'org', '4.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (31, 'ef178112-5e93-4a72-9723-f4147533514a', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', 'ef178112-5e93-4a72-9723-f4147533514a.vcf', '"1-8839c761111c08e4"', 'kim-invented@example.org', 'Kim Invented', 'Kim Invented', 'Kim', 'Invented', '', '', '[{"value": "kim@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'kim@example.invalid', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '8839c761111c08e401bb7dce974bf74c3a7c89a239f9719a1d379782a283db8e', NULL, 'individual', '3.0', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at, rev, raw_sha256, purge_after, kind, version, merged_into) VALUES (32, '5e5d53ae-f33f-4e36-821f-8ff520d1bb02', 'local', '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'owned://contacts/mydata', '5e5d53ae-f33f-4e36-821f-8ff520d1bb02.vcf', '"1-7e9a392c197a4d60"', '00000000-0000-4000-8000-00000000a006', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'sam.sample@example.com', CAST(X'' AS TEXT), '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', NULL, 1, '7e9a392c197a4d607c61b3f364a50cb309af8cc93793491b14bd435ee8be33e5', NULL, 'individual', '3.0', NULL);
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('054552df-9b70-42e1-b70a-0242d63787f9', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F764361726420656469746F722F2F454E0D0A4E3A5772697474656E3B5772656E3B3B3B0D0A464E3A5772656E205772697474656E0D0A5549443A34443243383242302D333630452D343231352D383941352D3041313434394636413636350D0A54454C3B545950453D43454C4C3A2B312035353520303137370D0A454D41494C3B545950453D484F4D453A7772656E406578616D706C652E6F72670D0A5245563A323032362D31302D31345431353A35303A33345A0D0A454E443A56434152440D0A' AS TEXT), 'create', 'mycontacts', NULL, NULL, '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('054552df-9b70-42e1-b70a-0242d63787f9', 2, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F764361726420656469746F722F2F454E0D0A4E3A5772697474656E3B5772656E3B3B3B0D0A464E3A5772656E205772697474656E0D0A5549443A34443243383242302D333630452D343231352D383941352D3041313434394636413636350D0A54454C3B545950453D43454C4C3A2B312035353520303137370D0A454D41494C3B545950453D484F4D453A7772656E406578616D706C652E6F72670D0A5245563A323032362D31302D31345431353A35303A33345A0D0A4E49434B4E414D453A5765655C2C205772656E0D0A424441593B582D4150504C452D4F4D49542D594541523D313630343A313630342D30322D32390D0A454E443A56434152440D0A' AS TEXT), 'update', 'mycontacts', NULL, NULL, '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('054552df-9b70-42e1-b70a-0242d63787f9', 3, NULL, 'delete', 'mydata', NULL, NULL, '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('a1ea97f3-9886-465f-b39f-cf553df9d287', 1, 'BEGIN:VCARD
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
', 'import', 'import:2c819975-e330-4999-9f3d-fb7b7387b290', NULL, '2c819975-e330-4999-9f3d-fb7b7387b290', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('5524de27-8975-4b97-8445-c36bd2c8b791', 1, 'BEGIN:VCARD
VERSION:3.0
N:Placeholder;Pat;;;
FN:Pat Placeholder
TEL;TYPE=WORK,VOICE:+1-202-555-0106
ORG:Example Holdings;Invented\, Unit
END:VCARD
', 'import', 'import:2c819975-e330-4999-9f3d-fb7b7387b290', NULL, '2c819975-e330-4999-9f3d-fb7b7387b290', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('a1ea97f3-9886-465f-b39f-cf553df9d287', 2, NULL, 'undo', 'undo-import:mydata', NULL, '2c819975-e330-4999-9f3d-fb7b7387b290', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('5524de27-8975-4b97-8445-c36bd2c8b791', 2, NULL, 'undo', 'undo-import:mydata', NULL, '2c819975-e330-4999-9f3d-fb7b7387b290', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('44409042-af20-4377-a010-b77bb1d0a50c', 1, 'BEGIN:VCARD
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
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('26a33067-8cfd-4e10-a170-c180c6b5a0da', 1, 'BEGIN:VCARD
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
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('64d5657b-9f82-496d-96a6-c381932333df', 1, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('7563283d-c73c-4065-9d37-29714ab62b75', 1, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('d2e4786e-6ea3-4ab2-9908-3066e8b75401', 1, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('1876c35f-8f2e-4af0-a09a-a6bfbddc3ce8', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('26758707-eebe-44fc-9c82-63ac1a0cdb6b', 1, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('4e05009a-b4aa-4248-8441-7f947399a32f', 1, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('ef178112-5e93-4a72-9723-f4147533514a', 1, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'import', 'import:5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', NULL, '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('5e5d53ae-f33f-4e36-821f-8ff520d1bb02', 1, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'merge', 'mycontacts', NULL, NULL, '2026-10-14T15:50:34+00:00');
INSERT INTO "revisions" (object_id, rev, raw, op, actor, approval_id, batch_id, at) VALUES ('d2e4786e-6ea3-4ab2-9908-3066e8b75401', 2, NULL, 'merge', 'mycontacts', NULL, NULL, '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (1, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '054552df-9b70-42e1-b70a-0242d63787f9', '4D2C82B0-360E-4215-89A5-0A1449F6A665.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (2, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '054552df-9b70-42e1-b70a-0242d63787f9', '4D2C82B0-360E-4215-89A5-0A1449F6A665.vcf', 'modify', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (3, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '054552df-9b70-42e1-b70a-0242d63787f9', '4D2C82B0-360E-4215-89A5-0A1449F6A665.vcf', 'delete', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (4, '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'a1ea97f3-9886-465f-b39f-cf553df9d287', 'a1ea97f3-9886-465f-b39f-cf553df9d287.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (5, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '5524de27-8975-4b97-8445-c36bd2c8b791', '5524de27-8975-4b97-8445-c36bd2c8b791.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (6, '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'a1ea97f3-9886-465f-b39f-cf553df9d287', 'a1ea97f3-9886-465f-b39f-cf553df9d287.vcf', 'delete', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (7, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '5524de27-8975-4b97-8445-c36bd2c8b791', '5524de27-8975-4b97-8445-c36bd2c8b791.vcf', 'delete', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (8, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '44409042-af20-4377-a010-b77bb1d0a50c', '44409042-af20-4377-a010-b77bb1d0a50c.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (9, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '26a33067-8cfd-4e10-a170-c180c6b5a0da', '26a33067-8cfd-4e10-a170-c180c6b5a0da.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (10, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '64d5657b-9f82-496d-96a6-c381932333df', '64d5657b-9f82-496d-96a6-c381932333df.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (11, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '7563283d-c73c-4065-9d37-29714ab62b75', '7563283d-c73c-4065-9d37-29714ab62b75.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (12, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '31e720b3-073e-4b1c-b470-29ed5055d2b3', '31e720b3-073e-4b1c-b470-29ed5055d2b3.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (13, '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'd2e4786e-6ea3-4ab2-9908-3066e8b75401', 'd2e4786e-6ea3-4ab2-9908-3066e8b75401.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (14, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '1876c35f-8f2e-4af0-a09a-a6bfbddc3ce8', '1876c35f-8f2e-4af0-a09a-a6bfbddc3ce8.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (15, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '26758707-eebe-44fc-9c82-63ac1a0cdb6b', '26758707-eebe-44fc-9c82-63ac1a0cdb6b.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (16, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '4e05009a-b4aa-4248-8441-7f947399a32f', '4e05009a-b4aa-4248-8441-7f947399a32f.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (17, '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'ef178112-5e93-4a72-9723-f4147533514a', 'ef178112-5e93-4a72-9723-f4147533514a.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (18, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '5e5d53ae-f33f-4e36-821f-8ff520d1bb02', '5e5d53ae-f33f-4e36-821f-8ff520d1bb02.vcf', 'add', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (19, '4eb85bae-7098-4a89-aa94-9d78ae390a77', '31e720b3-073e-4b1c-b470-29ed5055d2b3', '31e720b3-073e-4b1c-b470-29ed5055d2b3.vcf', 'delete', '2026-10-14T15:50:34+00:00');
INSERT INTO "changes" (token, collection_id, object_id, href, op, at) VALUES (20, '4eb85bae-7098-4a89-aa94-9d78ae390a77', 'd2e4786e-6ea3-4ab2-9908-3066e8b75401', 'd2e4786e-6ea3-4ab2-9908-3066e8b75401.vcf', 'delete', '2026-10-14T15:50:34+00:00');
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('e24d9b93-a7db-466f-a128-aa6e5f69f644', '054552df-9b70-42e1-b70a-0242d63787f9', 'create', 'mycontacts', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('4e7bbcac-c49b-41e2-94e9-30e3e31d8cb0', '054552df-9b70-42e1-b70a-0242d63787f9', 'update', 'mycontacts', 2, 1, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('b54ea18d-c566-45a4-8e97-cd2de86ec855', '054552df-9b70-42e1-b70a-0242d63787f9', 'delete', 'mydata', 3, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('df2b6950-14a2-4c05-b7c6-8f5284fac544', 'a1ea97f3-9886-465f-b39f-cf553df9d287', 'create', 'mycontacts', 1, NULL, '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', 'mydata', 2);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('8d33d6d2-e3d4-46ed-9b0e-f6f55607a607', '5524de27-8975-4b97-8445-c36bd2c8b791', 'create', 'mycontacts', 1, NULL, '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', 'mydata', 2);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('0af1d1bd-d374-4e05-9260-fc6f2b1d6594', '44409042-af20-4377-a010-b77bb1d0a50c', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('d22bc0dd-660e-4beb-bf3a-1bf0dd26cb99', '26a33067-8cfd-4e10-a170-c180c6b5a0da', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('190c4b1b-c4cf-4019-9944-06566abdb706', '64d5657b-9f82-496d-96a6-c381932333df', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('442ef044-302e-484d-b2a4-c6bc34977879', '7563283d-c73c-4065-9d37-29714ab62b75', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('5466911b-d7d0-4b33-be21-214844b6fb30', '31e720b3-073e-4b1c-b470-29ed5055d2b3', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('89b2a77e-2057-4126-a276-9431ab5246ee', 'd2e4786e-6ea3-4ab2-9908-3066e8b75401', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('72886285-dd74-4fd8-b144-e22e74a2f458', '4e05009a-b4aa-4248-8441-7f947399a32f', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "undo_log" (id, object_id, op, actor, rev, prior_rev, at, undone_at, undone_by, undone_rev) VALUES ('895ffa65-7742-4fbb-873c-048f50855f05', 'ef178112-5e93-4a72-9723-f4147533514a', 'create', 'mydata', 1, NULL, '2026-10-14T15:50:34+00:00', NULL, NULL, NULL);
INSERT INTO "imports" (id, source, label, started_at, finished_at, counts, status, actor, source_account, address_book_id, undone_at, undone_by) VALUES ('2c819975-e330-4999-9f3d-fb7b7387b290', 'file', 'samsung.vcf', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', '{"cards": 2, "contacts": 2, "groups": 0, "skipped": 0, "new": 2, "duplicates": 0, "in_file": 0, "unchanged": 0, "updates": 0, "conflicts": 0, "deleted": 0, "suggestions": 0, "followed_matches": 1, "missing": 0, "to_import": 2, "to_update": 0, "to_link": 0, "created": 2, "groups_created": 0, "updated": 0, "linked": 0, "not_written": 0, "undo": {"removed": 2, "groups_removed": 0, "reverted": 0, "unlinked": 0, "kept": 0, "gone": 0}}', 'undone', 'mycontacts', '', '4eb85bae-7098-4a89-aa94-9d78ae390a77', '2026-10-14T15:50:34+00:00', 'mydata');
INSERT INTO "imports" (id, source, label, started_at, finished_at, counts, status, actor, source_account, address_book_id, undone_at, undone_by) VALUES ('5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', 'iCloud account', '2026-10-14T15:50:34+00:00', '2026-10-14T15:50:34+00:00', '{"cards": 10, "contacts": 8, "groups": 2, "skipped": 0, "new": 10, "duplicates": 0, "in_file": 0, "unchanged": 0, "updates": 0, "conflicts": 0, "deleted": 0, "suggestions": 0, "followed_matches": 1, "missing": 0, "to_import": 10, "to_update": 0, "to_link": 0, "created": 8, "groups_created": 2, "updated": 0, "linked": 0, "not_written": 0}', 'committed', 'mydata', 'acc-1', '4eb85bae-7098-4a89-aa94-9d78ae390a77', NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('a1ea97f3-9886-465f-b39f-cf553df9d287', '2c819975-e330-4999-9f3d-fb7b7387b290', 'file', 'sha256:a1e9dc08ab79d9c8bc4a5db5f58886f980a44fa717a264423c756efc8b9f9dfa', '5b02a6b879529e7c94d63561c28753ee5d51bfa834e7eaf6db287b5ffb2dcff0', 'BEGIN:VCARD
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
', 1, '', 'create', NULL, '2026-10-14T15:50:34+00:00', NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('5524de27-8975-4b97-8445-c36bd2c8b791', '2c819975-e330-4999-9f3d-fb7b7387b290', 'file', 'sha256:eabd7b2a17d667d18ac934322ff4e3604137762737d4062396113bf290ad7d90', '09981a5f1cb53451a63286c3631390e1e26aec4b3ed886515497509024e8fb19', 'BEGIN:VCARD
VERSION:2.1
N:Placeholder;Pat;;;
FN:Pat Placeholder
TEL;WORK;VOICE:+1-202-555-0106
ORG:Example Holdings;Invented, Unit
END:VCARD
', 1, '', 'create', NULL, '2026-10-14T15:50:34+00:00', NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('44409042-af20-4377-a010-b77bb1d0a50c', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', '3F1C0F0E-0000-4000-8000-00000000A001', '8808c62faa0bd280f5277e9d2896e93ead2cf44d71de7abaa0bf7839863fcaa2', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('26a33067-8cfd-4e10-a170-c180c6b5a0da', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', 'urn:uuid:00000000-0000-4000-8000-00000000a002', '660dec8182e8e805ba56cc4539f93f40e97f12e4d87f244495f96c5da09b3e8b', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('64d5657b-9f82-496d-96a6-c381932333df', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', '00000000-0000-4000-8000-00000000a003', '602ead1aafe389bcabfe067ed80bfa02b7d4a075274b4b3787a6b0aaac17ee54', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('7563283d-c73c-4065-9d37-29714ab62b75', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', '00000000-0000-4000-8000-00000000a005', 'e56104f08ffb716728f06c038e0e9304bb94f29ad1d0439e6d518a488e7d5231', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('31e720b3-073e-4b1c-b470-29ed5055d2b3', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', '00000000-0000-4000-8000-00000000a006', '7e9a392c197a4d607c61b3f364a50cb309af8cc93793491b14bd435ee8be33e5', NULL, 1, 'acc-1', 'create', NULL, NULL, '5e5d53ae-f33f-4e36-821f-8ff520d1bb02');
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('d2e4786e-6ea3-4ab2-9908-3066e8b75401', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', '00000000-0000-4000-8000-00000000a007', '65a38df8888f338c4604106e3082f66325da9fd0be48660b86c24175b2fd7fbf', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('1876c35f-8f2e-4af0-a09a-a6bfbddc3ce8', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', 'group-book-club@example.org', '8cc88a6e32584ccbf95df6c18d9ec933e203008b9d96538449eb9ce745835f18', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('26758707-eebe-44fc-9c82-63ac1a0cdb6b', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', 'urn:uuid:group-choir-1', '9a18e2ccfc36bd19c9fba4bf7bb9fbf5f888091378ba5e9e4fbf4949e81bf66c', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('4e05009a-b4aa-4248-8441-7f947399a32f', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', 'urn:uuid:org-library-1', '2001e615e3fc5dfa816cba133c4e9eb431044e95095c523081dee3690f34432f', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "origins" (object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev, source_account, action, prior_rev, undone_at, held_by) VALUES ('ef178112-5e93-4a72-9723-f4147533514a', '5d0fb82a-26fb-4657-a3aa-f0e84a5ebc69', 'icloud', 'kim-invented@example.org', '8839c761111c08e401bb7dce974bf74c3a7c89a239f9719a1d379782a283db8e', NULL, 1, 'acc-1', 'create', NULL, NULL, NULL);
INSERT INTO "merges" (id, merged_id, merged_rev, originals, links, actor, at, undone_at, undone_by) VALUES ('2a0eb86c-5aa7-4242-b237-e75de865c97b', '5e5d53ae-f33f-4e36-821f-8ff520d1bb02', 1, '[{"id": "31e720b3-073e-4b1c-b470-29ed5055d2b3", "rev": 2}, {"id": "d2e4786e-6ea3-4ab2-9908-3066e8b75401", "rev": 2}]', '{}', 'mycontacts', '2026-10-14T15:50:34+00:00', NULL, NULL);
