# CourtSide — Full Audit & Hardening Report

Mobile-first Flutter + Supabase court reservation app. This document audits the codebase and Supabase against the required business rules, schema, and quality checklist, then lists hardening actions.

---

## 1. Supabase Audit

### 1.1 Schema vs Required

| Table / Area | Required (spec) | Current | Gap |
|--------------|-----------------|---------|-----|
| **users** | id = auth.users.id (FK to auth), role DEFAULT 'player' | id = gen_random_uuid() in base schema; app inserts with auth.uid() on signup | Base schema shows gen_random_uuid(); migrations don’t change it. App correctly uses auth.uid() on insert. No FK to auth.users in public.users. |
| **users** | created_at | Yes | — |
| **courts** | name UNIQUE, max_hours int DEFAULT 4, is_active boolean DEFAULT true | name not unique; no max_hours, is_active | **Add:** unique(name), max_hours, is_active. |
| **courts** | ON DELETE RESTRICT | ON DELETE CASCADE (schema.sql) | **Change:** RESTRICT so reservations block court delete. |
| **categories** | name UNIQUE | Yes (migration 00004) | — |
| **reservations** | court_id ON DELETE RESTRICT | CASCADE in base schema | **Change:** RESTRICT. |
| **reservations** | category_id ON DELETE SET NULL | Yes | — |
| **reservations** | price_per_hour + total_price GENERATED | Single `price` (total) stored | Spec wants price_per_hour + computed total_price. **Optional:** add price_per_hour, total_price GENERATED; keep price for backward compat or migrate. |
| **reservations** | no_past_booking CHECK (date >= CURRENT_DATE) | Not present | **Add** for hardening. |
| **reservations** | valid_time_range CHECK (end_time > start_time) | Enforced in RPC/trigger | **Add** CHECK for clarity. |
| **reservations** | max_4_hours CHECK (duration <= 4) | Not present | **Add** (or use court.max_hours). |
| **reservations** | whole_hours_start/end CHECK (minute = 0) | Not enforced in DB | **Add** if strict whole-hour only. |
| **reservations** | UNIQUE (court_id, date, start_time) WHERE status NOT IN ('REJECTED','CANCELLED') | No unique; overlap enforced by trigger + RPC | Overlap trigger already prevents double book. **Optional:** partial unique for same start_time. |
| **reservations** | updated_at | Not present | **Optional.** |
| **reservation_change_requests** | new_date date | Not in migration 101000 | **Add** new_date for date moves. |
| **notifications** | type CHECK (enum list) | type text, no check | **Optional:** CHECK for known types. |
| **analytics_daily** | approved_bookings, cancelled_bookings, peak_hour, updated_at | total_bookings, busiest_hour, most_booked_sport; no approved/cancelled/updated_at | **Optional:** extend analytics. |

### 1.2 Functions & Triggers

| Required | Current | Gap |
|----------|---------|-----|
| check_slot_overlap(court_id, date, start, end, exclude_id?) with FOR UPDATE | check_reservation_overlap (no row lock) | Overlap is correct; **optional:** add FOR UPDATE in overlap check for stronger serialization. |
| get_occupied_slots(court_id, date) | get_occupied_slots, excludes REJECTED/CANCELLED (status in PENDING, APPROVED, ADMIN) | Matches. |
| compute_price → price_per_hour | calculate_booking_price returns **total** price (day 150 / night 100, 6–18 = day) | Spec: day 06:00–17:59, night 18:00–22:00. Current night is 18:00+ (no 22:00 cap). **Align:** cap night at 22:00 if required. |
| before_insert_reservation: set price, validate overlap | Overlap in trigger reservations_assert_no_overlap; price set in app then insert | **Optional:** before_insert trigger to set price from RPC. |
| after_update_reservation_status → insert notification | No DB trigger for status change → notification | Notifications created in app (admin approve/reject). **Optional:** trigger for consistency. |
| expire_change_requests (scheduled) | App can call expirePendingWhereExpired(); no Edge Function | **Missing:** scheduled Edge Function every 15 min. |
| send_reminders (24h / 1h before) | Not implemented | **Missing:** scheduled Edge Function + reminder notifications. |

### 1.3 RLS & Security

- **users:** Select own or admin; update own; insert own (id = current_user_id()). Good.
- **courts:** Select all; admin manage. Good.
- **reservations:** Select own or admin; insert own; update own PENDING or admin. Good.
- **reservation_change_requests:** Admin insert; select own or admin; player update own PENDING; admin update. Good.
- **notifications:** Select/update own; admin insert. Player insert (for “reservation created”) in 00003. Good.
- **reservation_history:** Admin select; insert allowed for audit trigger. Good.
- **analytics_daily:** Admin read. Good.

### 1.4 Concurrency & Data Integrity

- **Double booking:** Trigger `reservations_no_double_booking` (before insert/update) raises if overlap. RPC check_reservation_overlap used in app. **Good.**
- **Status transitions:** Not enforced in DB (optional trigger commented out in 20250315100000). Enforced in app (e.g. only PENDING editable).
- **Admin approve already-cancelled:** No DB trigger blocking. App can pass stale state. **Recommend:** before update check status in DB or use trigger.

---

## 2. Flutter App Audit

### 2.1 Auth

| Requirement | Current | Gap |
|-------------|---------|-----|
| Register: name, email, contact, password | Yes | — |
| Email uniqueness server-side | Supabase + insert users; duplicate fails | Register shows friendly message for duplicate. **Fix:** login shows raw `e.toString()`; use friendly message. |
| On success → auto-login → player home | signUp then context.go('/home'); session may exist if email confirm off | OK if email confirm disabled. |
| Login: wrong credentials specific error | setState(() => _error = e.toString()) | **Fix:** map AuthException to "Invalid email or password" (no raw exception). |
| Forgot password | Not implemented | **Missing:** "Forgot password?" → magic link. |
| Route guard: unauthenticated → /login | go_router redirect | Good. |
| Admins / → /admin | Redirect when role admin | Good. |

### 2.2 Player — Reservations Screen

| Requirement | Current | Gap |
|-------------|---------|-----|
| Court dropdown / single court | Single court (first of list) | OK for MVP. |
| Category required, form disabled if none | Category dropdown; no categories → message | **Harden:** disable submit when no categories. |
| Calendar today → +1 year, past disabled | firstDay/lastDay, enabledDayPredicate | Good. |
| Availability grid, only valid slots for end | Availability section; start/end dropdowns from available | Good. |
| Duration pill, price preview before submit | No duration pill; no "₱150 × 2h = ₱300" | **Add:** price preview before submit (use calculate_booking_price or stored after create). |
| Min 1h, max 4h (configurable per court) | No client-side max; backend has no max_hours check | **Add:** client max 4h (or from court); DB has trigger in 20250315100000 for overlap only. |
| Submit → ConfirmDialog → snackbar | ConfirmDialog then create; snackbar on success | Good. barrierDismissible: false. |
| Slot conflict at submit → clear error, refresh | Repo throws; UI shows "Time slot already booked"; list refetches | Good. |
| Tabs Book / My Bookings (narrow), side-by-side wide | Tabs with _tabController; wide layout side-by-side | Good. |
| Filter chips All/Pending/Approved/… | FilterChip row | Good. |
| PENDING only: Edit + Cancel | Edit only PENDING; Cancel only PENDING | Good. |
| APPROVED: change request banner, accept/reject | _ChangeRequestBanner | Good. |
| Pull-to-refresh | RefreshIndicator on notifications; reservations invalidate on refresh button | **Add:** RefreshIndicator on My Bookings list. |
| Empty state per filter | EmptyState for no reservations / no for filter | Good. |

### 2.3 Player — Notifications

| Requirement | Current | Gap |
|-------------|---------|-----|
| Sections: Change Requests / Notifications | Change request notifs first, then others | Good. |
| Unread count in AppBar | Not on player home AppBar (only icon) | **Optional:** badge. |
| Change request: old↔new, countdown, accept/reject | NotificationCard + ReservationChangeModal | Good. |
| Expired: badge, no action buttons | UI shows "Expired" / buttons hidden when expired | Good. |
| Mark as read on tap | On action (accept/reject); can add on card tap | **Optional:** mark read on tap. |

### 2.4 Admin Screens

| Screen | Requirement | Current | Gap |
|--------|-------------|---------|-----|
| Dashboard | Metric cards, busiest days, quick nav, real-time | Cards, busiest days chips, Wrap buttons, realtime | Good. |
| Pending | Oldest first, Approve/Reject/Edit, ConfirmDialog, conflict on approve | Sorted in provider?; actions present; conflict not rechecked on approve | **Harden:** before approve re-check slot free (RPC), show conflict error. |
| Schedule | Prev/Next day, filter by event type, cards with status color | Date picker, event type dropdown, ReservationListCard, StatusIndicator | Good. |
| Users | List, role badge, edit name/contact, history bottom sheet | List, badge, edit dialog, history in sheet | Good. |
| Courts | CRUD, soft-delete (is_active), block delete if bookings | CRUD; no is_active / soft-delete; delete allowed | **Harden:** add is_active; block delete if court has PENDING/APPROVED. |
| Categories | CRUD, delete warn "X reservations use" | CRUD; delete with confirm | **Optional:** show count on delete. |
| Admin reservations | ADMIN status, filter, edit → change request | List ADMIN, filter, AdminEditReservationDialog | Good. |

### 2.5 Error Handling Matrix

| Scenario | Required | Current |
|----------|----------|---------|
| Slot taken between check and submit | Inline error, refresh grid | Repo throws; UI shows message; invalidate availability | Good. |
| Network timeout on booking | Retry, no duplicate | No retry button; no idempotency key | **Optional:** retry + idempotency. |
| Auth token expired | Auto-refresh; else /login | Supabase client handles; redirect on 401 | OK. |
| Category deleted while form open | Dropdown reset, banner | Provider refetch; selection can go stale | **Harden:** reset category if current deleted. |
| Court deactivated | Error at submit | No is_active check yet | After adding is_active, check on submit. |
| Change request expired | "Expired" badge, no buttons | Shown | Good. |
| Admin approves already-cancelled | Blocked by DB | Not blocked | **Optional:** trigger or optimistic check. |
| Player cancels within 2h of slot | Warning: "Late cancellation — subject to review" | No warning | **Add:** check slot start vs now; show ConfirmDialog warning. |
| Double-tap submit | Button disabled, re-enable on error | _booking = true during create | Good. |
| Past date to API | DB constraint + client message | No no_past_booking CHECK yet | After migration, show "Cannot book past dates". |

### 2.6 Quality Checklist

| Item | Status |
|------|--------|
| No raw "Error: $e" to users | **Fail:** login, register (generic), admin screens (e.toString()), SnackBars in change accept/reject, notifications. |
| All async: loading, error, empty, data | Most screens use .when( data, loading, error ); empty state present. |
| Realtime channels disposed | Yes (providers ref.onDispose; screens dispose _channel). |
| Forms validate before ConfirmDialog | Reservation: validation in service. Others: confirm then act. |
| ConfirmDialogs barrierDismissible: false | Yes. |
| Dropdowns not stale after updates | Categories/courts from providers; invalidate on change. |
| Pull-to-refresh on list screens | Notifications yes; My Bookings has refresh button only. |
| Modals safe-area / keyboard | viewPadding in modals; check bottom sheets. |

---

## 3. Priority Hardening List

### P0 (Do first)

1. **User-friendly auth errors:** Map Supabase AuthException to "Invalid email or password" (login); keep duplicate-email message (register); avoid raw e.toString().
2. **Late cancellation warning:** When user cancels, if slot start is within 2 hours, show ConfirmDialog: "Late cancellation — subject to review."
3. **Generic error message helper:** Replace raw `e.toString()` in async .error() and SnackBars with a short user message (e.g. "Something went wrong. Try again.") and log full error.

### P1 (Schema / behavior)

4. **DB: courts** — Add `max_hours int DEFAULT 4`, `is_active boolean DEFAULT true`, `UNIQUE(name)`. Change reservations.court_id to ON DELETE RESTRICT (and courts.id if needed).
5. **DB: reservations** — Add CHECK (date >= CURRENT_DATE), CHECK (end_time > start_time), CHECK (duration <= 4) and optionally whole_hour checks.
6. **DB: reservation_change_requests** — Add `new_date date` for date moves.
7. **Admin approve conflict:** Before setting status APPROVED, re-check slot with check_reservation_overlap; if taken, show error and don’t update.

### P2 (Nice to have)

8. **Price preview:** Before submit, call RPC or compute and show "₱X × Yh = ₱Z".
9. **Pull-to-refresh** on My Bookings list.
10. **Courts soft-delete:** Use is_active; block hard delete when court has active reservations.
11. **Scheduled functions:** expire_change_requests (15 min), send_reminders (hourly) via Edge Functions.
12. **Notification trigger:** After update reservations set status → insert notification (approve/reject).

---

## 4. File Reference

- **Supabase:** `supabase/schema.sql`, `supabase/migrations/*.sql`
- **Auth:** `lib/features/auth/` (login_screen, register_screen, auth_repository)
- **Reservations:** `lib/features/reservations/` (repository, service, player_reservations_screen)
- **Reservation change:** `lib/features/reservation_change/`, `lib/features/admin/presentation/widgets/admin_edit_reservation_dialog.dart`
- **Notifications:** `lib/features/notifications/`
- **Admin:** `lib/features/admin/presentation/`
- **Router:** `lib/core/router/app_router.dart`
- **ConfirmDialog:** `lib/core/widgets/confirm_dialog.dart` (barrierDismissible: false)

---

## 5. Edge Cases to Test

- Two players submit same slot → only one succeeds (trigger + RPC).
- Admin approves while player cancels → DB/trigger or version check.
- Player edits reservation after admin sends change request → change request remains; optional: expire on edit.
- Category deleted while form open → reset selection, show warning.
- Court max_hours (e.g. 5h booking) → UI prevent + DB reject once CHECK added.
- Booking end 22:00 vs 23:00 → spec says 22:00 last; align get_occupied_slots / booking hours.
- Admin deactivates court with future bookings → existing bookings unaffected; new bookings blocked (once is_active used).
- Role admin on player route → redirect to /admin (implemented).

This audit is the single source of truth for gaps and hardening order. Implement P0 then P1, then P2 as needed.
