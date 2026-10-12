"""Canned data behind the fake tools. Fixed "today" is Wednesday 18 March 2026."""

from __future__ import annotations

from datetime import date

TODAY = date(2026, 3, 18)

CONTACTS = [
    {"id": "c-rishita", "name": "Rishita Shah", "email": "rishita.shah@example.com", "phone": "+91 98200 11111"},
    {"id": "c-priya", "name": "Priya Nair", "email": "priya.nair@example.com", "phone": "+91 98200 22222"},
    {"id": "c-arjun", "name": "Arjun Rao", "email": "arjun.rao@example.com", "phone": "+91 98200 33333"},
    {"id": "c-tom", "name": "Tom Becker", "email": "tom.becker@example.com", "phone": "+44 7700 900123"},
    {"id": "c-amit", "name": "Amit Patel", "email": "amit.patel@example.com", "phone": "+91 98200 44444"},
    {"id": "c-nisha", "name": "Nisha Patel", "email": "nisha.patel@example.com", "phone": "+91 98200 55555"},
    {"id": "c-raj", "name": "Raj Patel", "email": "raj.patel@example.com", "phone": "+91 98200 66666"},
    {"id": "c-alexc", "name": "Alex Chen", "email": "alex.chen@example.com", "phone": "+1 415 555 0101"},
    {"id": "c-alexm", "name": "Alex Morgan", "email": "alex.morgan@example.com", "phone": "+1 415 555 0102"},
    {"id": "c-saml", "name": "Sam Lee", "email": "sam.lee@example.com", "phone": "+1 415 555 0103"},
    {"id": "c-samf", "name": "Samantha Fox", "email": "samantha.fox@example.com", "phone": "+1 415 555 0104"},
    {"id": "c-kapoor", "name": "Dr. Meera Kapoor (dentist)", "email": "reception@smilecare.example.com", "phone": "+91 22 5555 0199"},
]

EVENTS = [
    {"id": "e-yoga", "title": "Yoga class", "date": "2026-03-20", "start": "07:00", "end": "08:00", "location": "Studio Prana"},
    {"id": "e-party", "title": "Arjun's birthday party", "date": "2026-03-21", "start": "18:00", "end": "22:00", "location": "Arjun's flat, Bandra"},
    {"id": "e-standup", "title": "Team planning", "date": "2026-03-23", "start": "10:00", "end": "11:00", "location": "Video call"},
    {"id": "e-dentist", "title": "Dentist appointment (Dr. Kapoor)", "date": "2026-03-26", "start": "15:30", "end": "16:15", "location": "SmileCare Clinic"},
    {"id": "e-lunch", "title": "Lunch with Priya", "date": "2026-03-27", "start": "13:00", "end": "14:00", "location": "Cafe Zoe, Lower Parel"},
    {"id": "e-review", "title": "Quarterly review", "date": "2026-03-31", "start": "11:00", "end": "12:00", "location": "Office"},
    {"id": "e-books", "title": "Book club", "date": "2026-04-02", "start": "19:00", "end": "21:00", "location": "Kitab Khana"},
    {"id": "e-gym", "title": "Personal training", "date": "2026-03-19", "start": "06:30", "end": "07:30", "location": "Gym"},
    {"id": "e-call", "title": "Call with mum", "date": "2026-03-19", "start": "20:00", "end": "20:30", "location": ""},
]

MAIL = [
    {"id": "m-hdfc-1", "from": "HDFC Bank <alerts@hdfcbank.example.com>", "date": "2026-03-05",
     "subject": "Your February account statement",
     "body": "Dear customer, your statement for February 2026 is attached."},
    {"id": "m-hdfc-2", "from": "HDFC Bank <alerts@hdfcbank.example.com>", "date": "2026-03-12",
     "subject": "Credit card payment due on 22 March",
     "body": "A payment of Rs 18,420 is due on 22 March 2026."},
    {"id": "m-hdfc-3", "from": "HDFC Bank <alerts@hdfcbank.example.com>", "date": "2026-02-20",
     "subject": "New login from Chrome on macOS",
     "body": "We noticed a new login to your net banking account."},
    {"id": "m-tom-1", "from": "Tom Becker <tom.becker@example.com>", "date": "2026-03-10",
     "subject": "Project budget: revised numbers",
     "body": "Hi, attached are the revised budget numbers for the website project. Total is now 4,200 EUR."},
    {"id": "m-tom-2", "from": "Tom Becker <tom.becker@example.com>", "date": "2026-03-16",
     "subject": "Weekend plans?",
     "body": "Are you around this weekend?"},
    {"id": "m-indigo", "from": "IndiGo <noreply@goindigo.example.com>", "date": "2026-03-02",
     "subject": "Booking confirmed: Bengaluru to Mumbai, 6E 5321",
     "body": "Your flight 6E 5321 from Bengaluru (BLR) to Mumbai (BOM) on Tuesday 31 March 2026 "
             "departs at 09:40 and arrives at 11:25. PNR: X7K2QD."},
    {"id": "m-priya-1", "from": "Priya Nair <priya.nair@example.com>", "date": "2026-03-12",
     "subject": "Lease renewal",
     "body": "The landlord sent the renewal terms for the flat lease. Rent goes up 5% from May."},
    {"id": "m-priya-2", "from": "Priya Nair <priya.nair@example.com>", "date": "2026-03-16",
     "subject": "Re: lunch on the 27th",
     "body": "Cafe Zoe at 1pm works for me."},
    {"id": "m-sam", "from": "Sam Lee <sam.lee@example.com>", "date": "2026-03-17",
     "subject": "Meeting notes",
     "body": "Notes from today's meeting attached."},
]

PHOTOS = [
    {"id": "p-001", "taken": "2025-12-24", "place": "Goa, India", "people": ["Rishita Shah"], "tags": ["beach", "sunset"]},
    {"id": "p-002", "taken": "2025-12-26", "place": "Goa, India", "people": [], "tags": ["beach", "boats"]},
    {"id": "p-003", "taken": "2024-12-28", "place": "Goa, India", "people": ["Arjun Rao"], "tags": ["beach"]},
    {"id": "p-004", "taken": "2024-08-15", "place": "Mumbai, India", "people": ["Arjun Rao"], "tags": ["rain", "street"]},
    {"id": "p-005", "taken": "2024-11-02", "place": "Mumbai, India", "people": ["Arjun Rao", "Priya Nair"], "tags": ["diwali", "lights"]},
    {"id": "p-006", "taken": "2026-02-14", "place": "Pune, India", "people": ["Rishita Shah"], "tags": ["dinner"]},
    {"id": "p-007", "taken": "2025-05-03", "place": "Kerala, India", "people": [], "tags": ["beach", "sunset", "palm trees"]},
]
