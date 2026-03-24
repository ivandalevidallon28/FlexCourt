# CourtSide — Bulletproof System Design (Enterprise Level)

Production-ready design for the Court Reservation Management System. Aligns with existing **Flutter + Supabase** stack and closes gaps for double-booking prevention, state machine, auditability, and full notification coverage.

---

## 1. Application Overview

- **Courts:** Basketball, Volleyball, other rentable courts (via `courts.sport_type` + `categories`).
- **Pricing:** Day rate 150 PHP/hr (06:00–17:59), Night rate 100 PHP/hr (18:00–05:59). Implemented in `calculate_booking_price()`.
- **Capabilities:** Player reservations, admin approval/reject, real-time availability, notifications, schedule management, analytics.

---

## 2. Production-Ready Database Schema

### 2.1 Current + Extended Tables

| Table | Purpose | Audit / Constraints |
|-------|---------|--------------------|
| **users** | Auth-linked profile: name, email, contact_number, role (player/admin) | `created_at`, unique email, role check |
| **courts** | Venue: name, sport_type, description | `created_at`, RLS |
| **categories** | Activity type (Basketball, Volleyball, etc.) | `created_at`, unique name |
| **reservations** | Core booking: user_id, court_id, category_id, date, start_time, end_time, status, price | `created_at`, status check, **no-overlap trigger** |
| **reservation_history** | Full audit trail of status/field changes | `created_at`, immutable inserts only |
| **reservation_change_requests** | Admin-proposed time change; player Accept/Reject | `expires_at`, one PENDING per reservation (unique partial index) |
| **notifications** | In-app: title, message, type, reservation_id, change_request_id | `created_at`, is_read |
| **analytics_daily** | Pre-aggregated: total_bookings, busiest_hour, most_sport per date | Updated by trigger on reservations |
| **court_availability** (optional) | Override open/closed hours per court/date | For future maintenance windows |
| **pricing_rules** (optional) | Configurable day/night rate per court or global | Currently hardcoded in `calculate_booking_price` |

### 2.2 Reservation Status (Strict State Machine)

Allowed values: `PENDING`, `APPROVED`, `REJECTED`, `CANCELLED`, `ADMIN`, `COMPLETED`, `EXPIRED`.

**Valid transitions (enforced in app + optional DB trigger):**

```
PENDING     → APPROVED | REJECTED | CANCELLED
APPROVED   → COMPLETED | CANCELLED
ADMIN      → (admin can edit; treat like APPROVED for slot)
REJECTED   → (terminal)
CANCELLED  → (terminal)
COMPLETED  → (terminal)
EXPIRED    → (terminal)
```

**Invalid (blocked):** REJECTED→APPROVED, COMPLETED→CANCELLED, etc.

### 2.3 Concurrency Protection (No Double Booking)

- **Application:** Before insert/update, call RPC `check_reservation_overlap(court_id, date, start, end [, exclude_id])`. Only create/update if it returns `true`.
- **Database:** Trigger `reservations_no_double_booking` on INSERT/UPDATE runs the same overlap logic and **raises** on conflict, so even concurrent requests cannot create overlapping rows. Uses `FOR UPDATE` or equivalent in trigger for serialization.
- **Unique constraint:** A single (court_id, date, start_time, end_time) unique index does **not** work for overlapping ranges; overlap must be enforced by trigger/function.

### 2.4 Reservation Change (Admin Edit) Flow

1. Admin proposes new time → insert `reservation_change_requests` (status `PENDING`, `expires_at` = now + 24h).
2. One PENDING change per reservation (unique partial index).
3. Notification created (trigger or app) with `type = 'reservation_change_request'`, `change_request_id` set.
4. Player **Accepts** → `updateReservationTimes()` + change request status `ACCEPTED`; notification marked read; availability refreshes.
5. Player **Rejects** → change request status `REJECTED`; reservation unchanged; notification marked read.

---

## 3. Backend API Structure (Supabase)

Supabase provides **PostgREST** (REST over tables/views), **RPC** (stored procedures), and **Realtime**. No separate REST server required.

### 3.1 Auth

| Method | Endpoint / Usage | Purpose |
|--------|-------------------|--------|
| POST | `auth.signUp` (Supabase Auth) | Register |
| POST | `auth.signInWithPassword` | Login |
| POST | `auth.signOut` | Logout |

### 3.2 Users

| Method | Usage | Purpose |
|--------|--------|--------|
| GET | `from('users').select().eq('id', id)` | Profile (RLS: own or admin) |
| POST | Trigger on signup | Create row in `public.users` (via Edge Function or trigger) |
| PATCH | `from('users').update(...).eq('id', id)` | Update profile (RLS: own) |

### 3.3 Courts & Categories

| Method | Usage | Purpose |
|--------|--------|--------|
| GET | `from('courts').select()` | List courts (RLS: all read) |
| GET | `from('categories').select()` | List categories |
| POST/PATCH/DELETE | `from('courts')` / `from('categories')` | Admin only (RLS) |

### 3.4 Reservations

| Method | Usage | Purpose |
|--------|--------|--------|
| GET | `from('reservations').select().eq('user_id', uid)` | My reservations |
| POST | Insert after RPC overlap check | Create reservation (PENDING or ADMIN) |
| PATCH | `from('reservations').update(...).eq('id', id)` | Update (player: own PENDING; admin: any) |
| RPC | `check_reservation_overlap(p_court_id, p_date, p_start, p_end, p_exclude_reservation_id)` | No double booking check |
| RPC | `get_occupied_slots(p_court_id, p_date)` | Availability widget |
| RPC | `calculate_booking_price(p_date, p_start, p_end)` | Price before insert |

### 3.5 Admin

| Method | Usage | Purpose |
|--------|--------|--------|
| GET | `from('reservations').select().eq('status','PENDING')` (admin) | Pending list |
| PATCH | `from('reservations').update({status: 'APPROVED'}).eq('id', id)` | Approve |
| PATCH | `from('reservations').update({status: 'REJECTED'}).eq('id', id)` | Reject |
| POST | Insert `reservation_change_requests` | Admin change request |
| GET | `from('reservation_change_requests').select()` | Change requests (admin or player own) |

### 3.6 Notifications

| Method | Usage | Purpose |
|--------|--------|--------|
| GET | `from('notifications').select().eq('user_id', uid)` | My notifications |
| PATCH | `from('notifications').update({is_read: true}).eq('id', id)` | Mark read |

### 3.7 Analytics

| Method | Usage | Purpose |
|--------|--------|--------|
| GET | `from('analytics_daily').select()` | Dashboard (admin RLS) |
| (Trigger) | `refresh_daily_analytics` on reservation change | Keep aggregates correct |

---

## 4. Full UI Page Structure

### 4.1 Player

| Route | Screen | Purpose |
|-------|--------|--------|
| `/login` | LoginScreen | Sign in |
| `/register` | RegisterScreen | Name, email, contact, password |
| `/home` | PlayerReservationsScreen | Availability, create booking, My Reservations list, filters |
| `/courts` | CourtsListScreen | List courts |
| `/notifications` | NotificationsScreen | List notifications; Accept/Reject change requests; Mark read |

### 4.2 Admin

| Route | Screen | Purpose |
|-------|--------|--------|
| `/admin` | AdminDashboardScreen | Metrics, quick links |
| `/admin/pending` | AdminPendingReservationsScreen | Approve / Reject / Edit (change request) |
| `/admin/schedule` | AdminScheduleScreen | Calendar/list by date + event type |
| `/admin/users` | AdminUsersScreen | List users |
| `/admin/categories` | AdminCategoriesScreen | CRUD categories |
| `/admin/reservations` | AdminAdminReservationsScreen | Admin-created reservations |
| `/admin/notifications` | (optional) | Admin notifications |

### 4.3 Shared

- **GradientAppBar** + theme toggle.
- **Real-time:** Reservations and notifications use Supabase Realtime; availability refetches on invalidation after create/update/accept change.

---

## 5. State Diagrams

### 5.1 Reservation Lifecycle

```
                    ┌─────────────┐
                    │   PENDING   │
                    └──────┬──────┘
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
      ┌──────────┐ ┌──────────┐ ┌──────────┐
      │ APPROVED │ │ REJECTED │ │ CANCELLED│
      └────┬─────┘ └──────────┘ └──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌──────────┐ ┌──────────┐
│COMPLETED │ │ CANCELLED│
└──────────┘ └──────────┘
```

- **ADMIN** is like APPROVED for slot blocking; admin can edit.
- **EXPIRED** can be set by a cron/job for unapproved bookings past a deadline (optional).

### 5.2 Reservation Change Request

```
Admin proposes new time
        │
        ▼
┌───────────────────┐
│ PENDING (24h TTL) │
└─────────┬─────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌─────────┐ ┌─────────┐
│ACCEPTED │ │REJECTED │  (or EXPIRED)
└────┬────┘ └─────────┘
     │
     ▼
Reservation times updated; availability refreshed.
```

---

## 6. Edge Case Handling

| Scenario | Mitigation |
|----------|------------|
| **Two users reserve same slot** | RPC overlap check before insert; DB trigger raises on overlap. |
| **Admin moves booking into another** | Overlap check in `check_reservation_overlap` (exclude_id when editing). Reject with clear message. |
| **Booking expired (admin didn’t approve)** | Optional: cron sets status to EXPIRED; hide from “pending” after TTL. |
| **User cancels last minute** | Policy: allow cancel; optional “no cancel within X hours” enforced in app or trigger. |
| **Duplicate submit / retry** | Idempotent create: same user+court+date+time → same logical booking; overlap prevents double slot. |
| **Network failure** | Show clear error; don’t assume success; refetch list/availability. |
| **Expired change request** | Player cannot Accept; UI shows “Expired”; reject path still available. |
| **Concurrent accept of change request** | One PENDING per reservation; update status in one transaction; availability invalidated. |

---

## 7. Notification Workflow

| Event | Channel | Recipient | Content |
|-------|---------|-----------|--------|
| Booking created | In-app | Admin (optional) | New pending reservation |
| Booking approved | In-app | Player | “Reservation approved” |
| Booking rejected | In-app | Player | “Reservation rejected” |
| Admin change request | In-app | Player | “Proposed new time”; Accept/Reject |
| Change accepted | In-app | Admin (optional) | “Player accepted change” |
| Change rejected | In-app | Admin (optional) | “Player rejected change” |
| Booking cancelled | In-app | Player / Admin | “Reservation cancelled” |
| Reminder 24h / 1h before | In-app (optional email) | Player | Court, time, notes |

Types stored in `notifications.type` (e.g. `reservation_approved`, `reservation_change_request`). `reservation_id` and `change_request_id` link to detail.

---

## 8. Security

- **Auth:** Supabase JWT; password hashing by Supabase Auth.
- **RBAC:** `public.users.role` (player/admin); RLS on all tables.
- **RLS:** Players see own reservations/notifications; admin sees all. Admin-only: courts/categories management, analytics, change requests insert.
- **Input:** Validate in app; DB constraints (checks, FKs); RPC overlap/price.
- **Rate limiting:** Supabase project settings; optional Edge Function or API gateway for stricter limits.

---

## 9. QA Checklist (Summary)

- [ ] No double booking: overlap check + DB trigger.
- [ ] Status transitions: only allowed transitions in app (and optional trigger).
- [ ] Admin change: one PENDING per reservation; accept updates time and availability.
- [ ] Notifications: created for approve/reject/change request; marked read on action.
- [ ] Availability: `get_occupied_slots` includes PENDING/APPROVED/ADMIN; refreshed after create/update/accept.
- [ ] Approved booking: player cannot edit; only cancel or respond to change request.
- [ ] Audit: `reservation_history` records changes (migration provided).
- [ ] Pricing: day 150 / night 100 PHP in `calculate_booking_price`.

---

## 10. Files Reference

- **Schema / migrations:** `supabase/schema.sql`, `supabase/migrations/*.sql`
- **Reservations:** `lib/features/reservations/` (repository, service, providers, player screen)
- **Reservation change:** `lib/features/reservation_change/` (service, repository, modal)
- **Notifications:** `lib/features/notifications/` (repository, screen, notification_card)
- **Admin:** `lib/features/admin/presentation/` (dashboard, pending, schedule, users, categories, admin reservations)
- **Router:** `lib/core/router/app_router.dart`
- **Pricing:** `calculate_booking_price` in DB; day 6–18 → 150 PHP, else 100 PHP.

This design keeps the system consistent, auditable, and safe from double bookings and invalid states while matching your existing Flutter + Supabase implementation.
