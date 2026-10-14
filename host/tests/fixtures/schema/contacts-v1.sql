-- Synthetic contacts.sqlite at schema version 1, written by make_dump.py. Invented data only.
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at) VALUES (1, '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'acc-1', 'https://contacts.example.com/1/carddavhome/card/', 'Card', NULL, 't1', NULL, '{}', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at) VALUES (2, 'cf932d09-b869-4325-acde-1b43f04361fb', 'acc-2', 'https://contacts.example.com/1/carddavhome/work/', 'Work', NULL, 't1', NULL, '{"/2/card/zoe.vcf": "\"1\""}', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at) VALUES (3, '55519b73-c2c8-4e24-9339-ecd68948bb2f', 'mac', 'mac://contacts/container-icloud-0001', 'container-icloud-0001', NULL, NULL, NULL, '{"contact-ava-0001": "650fe18de1d16a3867cbba7e859e00a0", "contact-sam-0002": "1fb626b2c74fe2a59863c44f670d4704"}', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "address_books" (seq, id, account_id, url, name, color, sync_token, ctag, etags, created_at, modified_at, deleted_at) VALUES (4, '108206cb-26a4-4a9f-b5b2-0da48052ae4f', 'mac', 'mac://contacts/container-local-0002', 'container-local-0002', NULL, NULL, NULL, '{"contact-acme-0003": "0bcffba0f5ac233abc48214e5240266d", "contact-sam-0004": "eefd0483689400e1d4d58d5f3045d3b7"}', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (1, '4ee79093-8213-4f1d-85c3-6445315ce311', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/ava-fictional.vcf', '"1"', '3F1C0F0E-0000-4000-8000-00000000A001', 'Ava Fictional', 'Ava Fictional', 'Ava', 'Fictional', 'Avi', 'Example Widgets, Research', '[{"value": "ava@example.com", "label": "work"}, {"value": "ava.home@example.net", "label": "home"}, {"value": "ava.club@example.org", "label": "Chess club"}]', '[{"value": "+1 (555) 010-0100", "label": "mobile"}, {"value": "+44 20 7946 0000", "label": "home"}, {"value": "+1 555 0199", "label": "Gym locker"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Springfield", "region": "", "postal_code": "12345", "country": "Exampleland"}]', '--04-15', 'Met at the invented conference, row two.
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
', 'ava@example.com ava.home@example.net ava.club@example.org', '+1 (555) 010-0100 +44 20 7946 0000 +1 555 0199 15550100100 5550100100 550100100 50100100 0100100 442079460000 42079460000 2079460000 079460000 79460000 9460000 15550199 5550199', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (2, 'ad8443ef-9a67-4829-bffc-1b244e177c04', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/zoe-example-v4.vcf', '"1"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
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
', 'zoe@example.org zoe.home@example.net', '+44-20-7946-0123 442079460123 42079460123 2079460123 079460123 79460123 9460123', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (3, '9050da4b-ab20-4519-b41a-16be5f22aab5', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/org-only.vcf', '"1"', '00000000-0000-4000-8000-00000000a003', 'Example Bakery Ltd', '', '', '', '', 'Example Bakery Ltd', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
FN:
ORG:Example Bakery Ltd;
X-ABShowAs:COMPANY
TEL;type=WORK;type=VOICE:+1 555 0142
UID:00000000-0000-4000-8000-00000000a003
END:VCARD
', '', '+1 555 0142 15550142 5550142', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (4, '5fff1dba-0563-4325-9637-b6d8c937be97', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/phone-only.vcf', '"1"', '00000000-0000-4000-8000-00000000a004', '+1 555 0177', '', '', '', '', '', '[]', '[{"value": "+1 555 0177", "label": "mobile"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:;;;;
TEL;type=CELL:+1 555 0177
UID:00000000-0000-4000-8000-00000000a004
END:VCARD
', '', '+1 555 0177 15550177 5550177', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00');
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (5, '6f834696-c8e0-4a5a-9290-d61283112ec7', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/empty.vcf', '"1"', '00000000-0000-4000-8000-00000000a005', 'No name', '', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
UID:00000000-0000-4000-8000-00000000a005
END:VCARD
', '', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (6, 'a0e2d482-be01-4226-a41e-aef2233093d3', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/sam-sample-1.vcf', '"1"', '00000000-0000-4000-8000-00000000a006', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a006
END:VCARD
', 'sam.sample@example.com', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (7, '27b7ef15-8bc0-461b-b5f0-a91a9d3f7b78', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/sam-sample-2.vcf', '"1"', '00000000-0000-4000-8000-00000000a007', 'Sam Sample', 'Sam Sample', 'Sam', 'Sample', '', '', '[{"value": "sam.sample@example.com", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
N:Sample;Sam;;;
FN:Sam Sample
EMAIL;type=INTERNET:sam.sample@example.com
UID:00000000-0000-4000-8000-00000000a007
END:VCARD
', 'sam.sample@example.com', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (8, 'ac46615c-3b04-4ac6-87c6-b7c9da710934', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/group-3.vcf', '"x0"', 'group-book-club@example.org', 'Book club', 'Book club', '', 'Book club', '', '', '[]', '[]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F4170706C6520496E632E2F2F694F532031382E302F2F454E0D0A4E3A426F6F6B20636C75623B3B3B3B0D0A464E3A426F6F6B20636C75620D0A582D41444452455353424F4F4B5345525645522D4B494E443A67726F75700D0A5549443A67726F75702D626F6F6B2D636C7562406578616D706C652E6F72670D0A582D41444452455353424F4F4B5345525645522D4D454D4245523A75726E3A757569643A33463143304630452D303030302D343030302D383030302D3030303030303030413030310D0A454E443A56434152440D0A' AS TEXT), '', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (9, 'c0a93faa-54c8-40c9-b940-ffa0625cf4e1', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/group-4.vcf', '"x1"', 'urn:uuid:group-choir-1', 'Choir (example)', 'Choir (example)', '', '', '', '', '[]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:group
FN:Choir (example)
UID:urn:uuid:group-choir-1
MEMBER:urn:uuid:zoe-0001@example.org
END:VCARD
', '', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (10, '0114d803-e2a2-42c1-b40e-c30ffb694f85', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/org-4.vcf', '"x2"', 'urn:uuid:org-library-1', 'Example Library', 'Example Library', '', '', '', 'Example Library', '[]', '[{"value": "+1 555 0142", "label": "work"}]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:4.0
KIND:org
FN:Example Library
ORG:Example Library
UID:urn:uuid:org-library-1
TEL;TYPE=work:+1 555 0142
END:VCARD
', '', '+1 555 0142 15550142 5550142', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (11, '8950dda2-82c8-4008-b473-3f3828e985c5', 'acc-1', '444d31ea-f296-4a4d-8fa9-b01c0313ca7b', 'https://contacts.example.com/1/carddavhome/card/', '/1/carddavhome/card/kim.vcf', '"x3"', 'kim-invented@example.org', 'Kim Invented', 'Kim Invented', 'Kim', 'Invented', '', '', '[{"value": "kim@example.invalid", "label": ""}]', '[]', '[]', NULL, '', 0, 'BEGIN:VCARD
VERSION:3.0
FN:Kim Invented
N:Invented;Kim;;;
item1.X-ADDRESSBOOKSERVER-KIND:individual
UID:kim-invented@example.org
EMAIL;TYPE=INTERNET:kim@example.invalid
END:VCARD
', 'kim@example.invalid', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (12, '4c998913-6d38-4075-b2fc-eda88670bd96', 'acc-2', 'cf932d09-b869-4325-acde-1b43f04361fb', 'https://contacts.example.com/1/carddavhome/work/', '/2/card/zoe.vcf', '"1"', 'urn:uuid:00000000-0000-4000-8000-00000000a002', 'Zoë Exämple', 'Zoë Exämple', 'Zoë', 'Exämple', '', '', '[{"value": "zoe@example.org", "label": "work"}, {"value": "zoe.home@example.net", "label": "home"}]', '[{"value": "+44-20-7946-0123", "label": "mobile"}]', '[]', '1990-04-01', '', 1, 'BEGIN:VCARD
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
', 'zoe@example.org zoe.home@example.net', '+44-20-7946-0123 442079460123 42079460123 2079460123 079460123 79460123 9460123', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (13, 'd9b8173d-e180-4d87-a89a-4ad904590374', 'mac', '55519b73-c2c8-4e24-9339-ecd68948bb2f', 'mac://contacts/container-icloud-0001', 'contact-ava-0001', '650fe18de1d16a3867cbba7e859e00a0', 'contact-ava-0001', 'Ava Q Fictional', 'Ava Q Fictional', 'Ava', 'Fictional', 'Avi', 'Example Labs', '[{"value": "ava.fictional@example.com", "label": "home"}, {"value": "ava@work.example.net", "label": "work"}]', '[{"value": "+1 202 555 0101", "label": "mobile"}]', '[{"label": "home", "street": "1 Example Street", "locality": "Testville", "region": "", "postal_code": "00000", "country": "Exampleland"}]', '1990-04-12', '', 1, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D6176612D303030310D0A464E3A41766120512046696374696F6E616C0D0A4E3A46696374696F6E616C3B4176613B513B3B0D0A4E49434B4E414D453A4176690D0A4F52473A4578616D706C65204C6162730D0A5449544C453A496E76656E746F720D0A6974656D312E454D41494C3B545950453D494E5445524E45543A6176612E66696374696F6E616C406578616D706C652E636F6D0D0A6974656D312E582D41424C6162656C3A5F24213C486F6D653E21245F0D0A6974656D322E454D41494C3B545950453D494E5445524E45543A61766140776F726B2E6578616D706C652E6E65740D0A6974656D322E582D41424C6162656C3A5F24213C576F726B3E21245F0D0A6974656D332E54454C3A2B31203230322035353520303130310D0A6974656D332E582D41424C6162656C3A5F24213C4D6F62696C653E21245F0D0A6974656D342E4144523A3B3B31204578616D706C65205374726565743B5465737476696C6C653B3B30303030303B4578616D706C656C616E640D0A6974656D342E582D41424C6162656C3A5F24213C486F6D653E21245F0D0A424441593A313939302D30342D31320D0A6974656D352E55524C3A68747470733A2F2F7777772E6578616D706C652E6F72672F6176610D0A6974656D352E582D41424C6162656C3A686F6D65706167650D0A50484F544F3B454E434F44494E473D623B545950453D4A5045473A2F396A2F34476C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F0D0A20623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D0D0A2056756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C576C75646D56756447566B4C58426F623352764C574A350D0A206447567A4C576C75646D56756447566B4C58426F623352764C574A356447567A4C662F5A0D0A454E443A56434152440D0A' AS TEXT), 'ava.fictional@example.com ava@work.example.net', '+1 202 555 0101 12025550101 2025550101 025550101 25550101 5550101', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (14, 'a51ca522-3125-4068-ae79-9e4b68ab8c6b', 'mac', '55519b73-c2c8-4e24-9339-ecd68948bb2f', 'mac://contacts/container-icloud-0001', 'contact-sam-0002', '1fb626b2c74fe2a59863c44f670d4704', 'contact-sam-0002', 'Sam Example', 'Sam Example', 'Sam', 'Example', '', '', '[{"value": "sam.example@example.com", "label": ""}]', '[]', '[]', '--07-04', '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D73616D2D303030320D0A464E3A53616D204578616D706C650D0A4E3A4578616D706C653B53616D3B3B3B0D0A6974656D312E454D41494C3B545950453D494E5445524E45543A73616D2E6578616D706C65406578616D706C652E636F6D0D0A424441593A2D2D30372D30340D0A454E443A56434152440D0A' AS TEXT), 'sam.example@example.com', '', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (15, 'c3d29160-9bb0-435d-8e83-55fb71ba5db9', 'mac', '108206cb-26a4-4a9f-b5b2-0da48052ae4f', 'mac://contacts/container-local-0002', 'contact-acme-0003', '0bcffba0f5ac233abc48214e5240266d', 'contact-acme-0003', 'Acme Plumbing (Example)', 'Acme Plumbing (Example)', '', '', '', 'Acme Plumbing (Example)', '[]', '[{"value": "+44 7700 900123", "label": "work"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D61636D652D303030330D0A464E3A41636D6520506C756D62696E6720284578616D706C65290D0A4E3A3B3B3B3B0D0A4F52473A41636D6520506C756D62696E6720284578616D706C65290D0A582D414253686F7741733A434F4D50414E590D0A6974656D312E54454C3A2B34342037373030203930303132330D0A6974656D312E582D41424C6162656C3A776F726B0D0A454E443A56434152440D0A' AS TEXT), '', '+44 7700 900123 447700900123 47700900123 7700900123 700900123 00900123 0900123', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
INSERT INTO "contacts" (seq, id, account_id, address_book_id, collection_url, href, etag, uid, display_name, full_name, given_name, family_name, nickname, organisation, emails, phones, addresses, birthday, note, has_photo, raw_vcard, search_emails, search_phones, created_at, modified_at, deleted_at) VALUES (16, '2821d34d-39ed-43fa-932c-9943212141a9', 'mac', '108206cb-26a4-4a9f-b5b2-0da48052ae4f', 'mac://contacts/container-local-0002', 'contact-sam-0004', 'eefd0483689400e1d4d58d5f3045d3b7', 'contact-sam-0004', 'Sam Example', 'Sam Example', 'Sam', 'Example', '', '', '[]', '[{"value": "+44 7700 900103", "label": "mobile"}]', '[]', NULL, '', 0, CAST(X'424547494E3A56434152440D0A56455253494F4E3A332E300D0A50524F4449443A2D2F2F6D79446174612F2F54686973204D61632F2F454E0D0A5549443A636F6E746163742D73616D2D303030340D0A464E3A53616D204578616D706C650D0A4E3A4578616D706C653B53616D3B3B3B0D0A6974656D312E54454C3A2B34342037373030203930303130330D0A6974656D312E582D41424C6162656C3A5F24213C4D6F62696C653E21245F0D0A454E443A56434152440D0A' AS TEXT), '', '+44 7700 900103 447700900103 47700900103 7700900103 700900103 00900103 0900103', '2026-10-14T01:06:46+00:00', '2026-10-14T01:06:46+00:00', NULL);
