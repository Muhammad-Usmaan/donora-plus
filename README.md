# Donora+

**Real-time blood donation matching platform**
Built for the Healthcare Track — Alkhidmat Foundation Pakistan × Bano Qabil Hackathon
Sponsored by Alibaba Cloud

---

## Overview

Donora+ replaces informal, scattered social-media blood appeals with structured, location-aware infrastructure that connects verified blood seekers with nearby, cooldown-eligible donors in real time.

Pakistan's blood donation ecosystem today relies heavily on urgent Facebook/WhatsApp posts, with no way to verify donor identity, track donation history, or confirm eligibility. Donora+ solves this with verified accounts, live location-based matching, and automated cooldown enforcement — so a request for blood reaches real, eligible, nearby donors instead of a crowd of well-meaning but unverifiable strangers.

---

## Key Features

### Verified Dual-Role Accounts
- Single account, switchable between **Seeker** and **Donor** roles
- Identity verification via CNIC + live selfie capture

### Donation Matching
- Real-time, map-based donor discovery (flutter_map + OpenStreetMap — no Google Maps dependency)
- Supports **whole blood** and **platelet** donation types
- Type-specific cooldown enforcement: 90-day cooldown for whole blood, 7-day for platelets, with cross-type constraints correctly enforced
- Segmented Blood / Platelets tab UI on the home screen
- Cooldown status displayed separately per donation type

### Trust & Accountability
- Donor trust ratings — 1–5 star average plus an appreciation fraction, both derived from post-donation seeker feedback
- Public donor trust badge visible on donor profiles

### Motivation & Engagement
- Donation achievements and milestone system with user-set personal goals
- Auto-unlocking milestone tiers at the 1st, 5th, 10th, and 25th donation
- Shareable celebration screens with blood-type-themed artwork and dynamic text overlays

### AI-Powered Assistance
- In-app AI chatbot powered by Alibaba Cloud's Qwen model
- Multiple concurrent chat threads with a Recent Chats drawer
- Word-by-word response reveal for a natural conversational feel

### Communication
- In-app real-time chat between seekers and donors
- Unread message and notification indicators, with an "UNREAD MESSAGES" divider in chat threads
- Push notifications via Firebase Cloud Messaging

### Account Security
- Password reset via 6-digit email OTP (Supabase email OTP recovery flow)

### Admin Portal
- Web-based admin dashboard for platform oversight
- Audit logs with real-time updates
- User suspension / unsuspension controls

### Marketing Website
- Public-facing site reflecting all shipped platform features

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter, Riverpod (AsyncNotifier), GoRouter (StatefulShellRoute) |
| Backend | Supabase — Postgres, Auth, Storage, Realtime, Edge Functions, pg_cron |
| Push Notifications | Firebase Cloud Messaging |
| AI Chatbot | Alibaba Cloud — Qwen model |
| Maps | flutter_map + OpenStreetMap |
| Icons | Phosphor Icons (`phosphor_flutter`) |
| Transactional Email | Brevo (SMTP relay) |
| Marketing Website | Next.js (hosted on Vercel) |
| Admin Portal | HTML / CSS / JS (hosted on Vercel) |

---

## Project Structure

This repository contains the mobile application. Related components:

- **Marketing Website** — Next.js, deployed at [donoraplus.vercel.app](https://donoraplus.vercel.app)
- **Admin Portal** — [`Muhammad-Usmaan/donora-plus-admin`](https://github.com/Muhammad-Usmaan/donora-plus-admin), deployed on Vercel

---

## Team

| Member | Role |
|---|---|
| **Usman** | Team Lead — Full-Stack Architecture & Backend, primary Flutter/Supabase developer |
| **Hassan** | Marketing website & web admin portal |
| **Habiba** | UI/UX design, mobile screens |

---

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- A Supabase project (Postgres, Auth, Storage, Realtime, Edge Functions enabled)
- Firebase project configured for FCM
- Alibaba Cloud account with Qwen API access

### Setup

1. Clone the repository
   ```bash
   git clone https://github.com/Muhammad-Usmaan/donora-plus
   cd donora-plus
   ```

2. Configure environment variables — create a `.env` file (see `.env.example` if provided) with:
   - Supabase project URL and anon key
   - Firebase configuration
   - Any other required client-side config

   **Do not commit `.env` files or API keys.** See [Security Notes](#security-notes) below.

3. Install dependencies
   ```bash
   flutter pub get
   ```

4. Run the app
   ```bash
   flutter run --dart-define-from-file=.env
   ```

### Supabase Setup
- Apply the database schema and RLS policies as defined in the project's `System_Architecture` documentation
- Deploy Edge Functions via the Supabase CLI or Supabase MCP
- Configure OTP settings, SMTP (Brevo), and storage buckets via the Supabase dashboard

---

## Security Notes

- The Supabase **anon key** is safe for client-side use and is protected by Row Level Security (RLS) policies — this is the standard Supabase client model.
- The Supabase **service role key** must never be included in the Flutter binary or committed to this repository. It is used only in trusted server-side contexts (e.g. Vercel environment variables for the admin portal, marked Sensitive/Secret).
- Third-party API keys requiring server-side confidentiality (e.g. the Qwen API key) are proxied through a Supabase Edge Function rather than embedded in the client binary.
- Before pushing to a public repository, verify no secrets are committed — API keys, `.env` files, service-account JSON, or database credentials. Add these to `.gitignore`. Note that `.gitignore` only affects future commits; anything already pushed remains in git history and should be treated as compromised and rotated.

---

## Roadmap (Post-Hackathon)

- Phone OTP verification
- Regional round presentation and further platform refinement

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Acknowledgements

Built for the Alkhidmat Foundation Pakistan / Bano Qabil Hackathon, Healthcare Track, sponsored by Alibaba Cloud.
