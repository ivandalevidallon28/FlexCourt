# CourtSide — Technical Manual (Plain-Language Edition)

**Who this is for:** You are defending a real app you helped build. You don’t need to be a full-time programmer to explain it—you need a **clear story**: what the user sees, what happens on the internet, and where to look in the project if someone asks “which file?”

**How to read file paths:** Think of them like **addresses inside the project folder**. Example: `lib/features/auth/presentation/login_screen.dart` means: open the project → `lib` → `features` → `auth` → … → the **login screen** file.

---

## Stay safe (read this once)

- Do **not** put **passwords**, **secret keys**, or **“service role”** keys on slides, Facebook, or thesis PDFs as plain text.
- The app connects to Supabase using settings from the code (for example `lib/core/constants/env.dart`). That’s normal for development, but treat those values as **private**—like an ATM PIN for your project’s cloud account.

---

## Part 1 — The whole picture (no code yet)

### Imagine three layers

1. **What people see (the phone app)**  
   Buttons, colors, calendars, lists. Built with **Flutter** (a toolkit for making the screen). All of that lives mostly in a folder called `lib/`.

2. **The cloud office (Supabase)**  
   This is **not** on your phone. It’s online: it checks logins, stores data in a **database**, holds **files** (like receipt photos), and can **push live updates** so two people don’t see stale information forever.

3. **The filing cabinet (PostgreSQL database)**  
   Data is stored in **tables**—think Excel sheets with names like `users`, `reservations`, `notifications`.  
   **Important:** The database has **rules** about who may read which rows. That’s often called **Row Level Security (RLS)**—“security per row,” not “everyone sees everything.”

### Simple analogy: restaurant

- **Screen** = the menu the customer reads.  
- **Repository** = the waiter who runs to the kitchen and brings back exactly what you asked for (reads/writes the right **table**).  
- **Service** = the manager who says: “After order is placed, also ring the bell for the kitchen *and* tell the customer ‘pending.’” (extra steps and rules.)  
- **Provider (Riverpod)** = a clipboard that remembers “today’s bookings” and tells the screen to **refresh** when something changes.

### How information travels (one booking)

In plain words:

1. User taps **Submit** on the booking form.  
2. The app checks rules (time valid? slot free?).  
3. The app sends a **secure request** over the internet to Supabase.  
4. Supabase runs checks on the server (so cheating by editing the app is harder).  
5. A new row appears in the **`reservations`** table (or an error comes back).  
6. The screen updates—sometimes instantly via **Realtime** (“live refresh”).

**Technical names (if a panelist uses them):**  
HTTPS = encrypted internet traffic. **JWT** = a short-lived “badge” proving who is logged in. **RPC** = a ready-made **server function** (like a calculator on the cloud) the app can call by name, e.g. “is this slot free?”

---

## Part 2 — What’s inside the `lib/` folder (simple map)

Don’t memorize every name. Know **three big areas**:

| Area | Plain English | Typical folder |
|------|----------------|----------------|
| **Shared look & helpers** | Colors, buttons, dialogs used everywhere | `lib/core/` |
| **Login & signup** | Account creation, session | `lib/features/auth/` |
| **Booking & courts** | Main player experience | `lib/features/reservations/`, `lib/features/courts/`, `lib/features/categories/` |
| **Alerts** | In-app messages | `lib/features/notifications/` |
| **Admin tools** | Pending list, schedule, users, categories, courts, balls | `lib/features/admin/`, `lib/features/ball_rental/` |
| **Change requests** | Admin proposes new time; player accepts/rejects | `lib/features/reservation_change/` |
| **Traffic cop (navigation)** | Which page opens when; who may open `/admin` | `lib/core/router/app_router.dart` |
| **App start** | Turns Supabase on, starts the app | `lib/main.dart` |

### File name endings (easy patterns)

| Ends with… | Plain meaning |
|------------|----------------|
| `*_screen.dart` | A **full page** (a “screen” users navigate to). |
| `*_repository.dart` | Code whose job is **talk to the database** (read/add/update rows, call server functions). |
| `*_service.dart` | Code that **ties steps together** (e.g. “save booking, then create notification”). |
| `*_providers.dart` | Code that **loads data** for the screen and **refreshes** when data changes (Riverpod). |
| `*_model.dart` | A **blueprint** of one row (field names match the database, but spelled in app style). |

---

## Part 3 — Every “address” in the app (route → screen)

**Routes** are like **shortcuts** inside the app (`/home`, `/login`). They’re listed in `lib/core/router/app_router.dart`.

### Player / general

| You say this to the panel | Route | Where it lives (file) |
|----------------------------|-------|------------------------|
| Login page | `/login` | `features/auth/presentation/login_screen.dart` |
| Sign up page | `/register` | `features/auth/presentation/register_screen.dart` |
| Main home: book + my list | `/home` | `features/reservations/presentation/player_reservations_screen.dart` |
| One booking’s details | `/reservation/:id` | `features/reservations/presentation/reservation_details_screen.dart` *(the `:id` is the booking’s ID)* |
| List of courts | `/courts` | `features/courts/presentation/courts_list_screen.dart` |
| Notifications inbox | `/notifications` | `features/notifications/presentation/notifications_screen.dart` |
| Ball rental | `/balls` | `features/ball_rental/presentation/ball_rental_list_screen.dart` |

### Admin only (staff)

| You say this | Route | Where it lives (file) |
|--------------|-------|------------------------|
| Admin home / dashboard | `/admin` | `features/admin/presentation/admin_dashboard_screen.dart` |
| Approve or reject pending bookings | `/admin/pending` | `features/admin/presentation/admin_pending_reservations_screen.dart` |
| Schedule by date | `/admin/schedule` | `features/admin/presentation/admin_schedule_screen.dart` |
| Manage user accounts | `/admin/users` | `features/admin/presentation/admin_users_screen.dart` |
| Sport categories (Basketball, etc.) | `/admin/categories` | `features/admin/presentation/admin_categories_screen.dart` |
| Admin-created bookings | `/admin/reservations` | `features/admin/presentation/admin_admin_reservations_screen.dart` |
| Manage courts | `/admin/courts` | `features/admin/presentation/admin_courts_screen.dart` |
| Ball inventory | `/admin/balls` | `features/ball_rental/presentation/admin_balls_screen.dart` |

### How the app decides “admin or not”

- If you’re **not logged in**, you’re sent to **login** (except login/register pages).  
- If you’re logged in and try **`/admin/...`**, the app checks your **`users`** row: **`role`** must be **admin**. If not, you’re sent back to **home**.

**One sentence for defense:**  
> “Navigation is centralized in the router file, and admin pages are protected by checking the user’s role in the database.”

---

## Part 4 — Screen by screen: what users do vs what data is touched

For each block: **On screen** = user story. **Behind the scenes** = tables / cloud actions (plain words).

### Login & Register

- **On screen:** Email and password; register adds name and contact.  
- **Behind the scenes:** Supabase handles **login identity**. Signing up also **adds one row** to the **`users`** table (name, email, contact, role like `player`).  
- **Code to mention:** `features/auth/data/auth_repository.dart`

### Home (player) — biggest screen

- **On screen:** Pick date, court, sport category, time, fill details, submit; see “My Reservations.”  
- **Behind the scenes:**  
  - Reads **courts** and **categories**.  
  - Asks the server which times are already taken (**function** `get_occupied_slots`).  
  - Asks price (**function** `calculate_booking_price`).  
  - Before saving, asks “is this slot still free?” (**function** `check_reservation_overlap`).  
  - If OK, **adds a row** to **`reservations`**.  
  - Can **listen for live updates** on **`reservations`** so the list refreshes.  
- **Code to mention:** `reservations_repository.dart`, `reservation_service.dart`, `player_reservations_screen.dart`

### Reservation details

- **On screen:** See one booking; maybe edit, cancel, upload payment proof.  
- **Behind the scenes:** Reads/updates **`reservations`**; receipt photos go to **cloud storage** (bucket like `document`), and the **path** is saved on the reservation row.  
- **Code to mention:** `reservation_details_screen.dart`, `reservations_repository.dart`

### Courts list

- **On screen:** Read-only info about venues.  
- **Behind the scenes:** Reads **`courts`**.

### Notifications

- **On screen:** List of messages; mark read; sometimes **accept/reject** a proposed schedule change.  
- **Behind the scenes:** Reads **`notifications`** for your user; may update **`reservations`** and **`reservation_change_requests`** when you accept/reject. Can **subscribe to live updates**.  
- **Code to mention:** `notifications_screen.dart`, `notifications_repository.dart`, `reservation_change_service.dart`

### Ball rental (player)

- **On screen:** List balls, rent for fixed price, see active rental, return.  
- **Behind the scenes:** Reads **`balls`** and **`ball_rentals`**. **Rent** and **return** go through server **functions** `rent_ball` and `return_ball` so rules stay consistent. Live updates possible.  
- **Code to mention:** `ball_rental_list_screen.dart`, `balls_repository.dart`

### Admin dashboard

- **On screen:** Numbers and shortcuts (today’s bookings, pending count, busiest times, links).  
- **Behind the scenes:** Counts from **`reservations`**, reads summaries from **`analytics_daily`**.

### Admin pending

- **On screen:** List of bookings waiting for approval; approve or reject.  
- **Behind the scenes:** Reads **`reservations`** with status **PENDING** (with user/court names joined in). Updates **`reservations.status`**.

### Admin schedule

- **On screen:** Pick a date (and filters); see bookings that day.  
- **Behind the scenes:** Reads **`reservations`** for that date (with joins).

### Admin users / categories / courts / admin-reservations / balls

- **On screen:** Staff maintains master data or special booking types.  
- **Behind the scenes:** Add/change/delete rows in **`users`**, **`categories`**, **`courts`**, or specific **`reservations`**, **`balls`**, **`ball_rentals`** history as implemented.

### Small popups (not full pages)

- **Confirm dialog** — “Are you sure?” for rent/return/delete (`core/widgets/confirm_dialog.dart`).  
- **Admin edit reservation** — staff edits fields (`admin_edit_reservation_dialog.dart`).  
- **Change-request UI** — tied to schedule change flow (`reservation_change_modal.dart`).

---

## Part 5 — Reusable building blocks (widgets)

These are **not** full pages—they’re reused pieces so the app looks consistent.

| File (short name) | What it does in human words |
|-------------------|-----------------------------|
| `gradient_app_bar.dart` | Top bar with title (and often dark/light toggle). |
| `glass_card.dart` | Fancy card background for lists and metrics. |
| `confirm_dialog.dart` | Standard “Cancel / Confirm” popup. |
| `empty_state.dart` | Friendly “nothing here yet” illustration. |
| `loading_view` / `async_value_view` | Spinner or “still loading…” states. |
| `error_view.dart` | Shows errors in a calm way. |
| `reservation_list_card.dart` | One booking summary card in a list. |
| `status_indicator.dart` | Colored label for status (pending, approved, etc.). |

**Design tokens** (colors, fonts, spacing) live under `core/theme/` so the whole app matches.

---

## Part 6 — “Who talks to the database?” (cheat sheet)

Think: **Repository** = person who actually **opens the filing cabinet**. **Service** = person who **coordinates** several steps.

### Auth (`auth_repository.dart`)

| User action | Plain effect |
|-------------|--------------|
| Log in | Cloud checks email/password; phone gets a **session** (logged-in badge). |
| Sign up | Create auth account **and** add **`users`** row. |
| Log out | Clear session. |

### Reservations (`reservations_repository.dart`)

| Idea | Plain effect |
|------|--------------|
| My list | **Fetch** rows from **`reservations`** for my user. |
| Occupied times | **Ask server function** `get_occupied_slots`. |
| New booking | **Ask** `check_reservation_overlap` → **Ask** `calculate_booking_price` → **Insert** row into **`reservations`**. |
| Edit / cancel | **Update** row in **`reservations`**. |
| Receipt photo | **Upload file** to storage → **Save path** on **`reservations`**. |
| Live list | **Subscribe** to changes on **`reservations`**. |

### Courts & categories

| File | Plain effect |
|------|--------------|
| `courts_repository.dart` | Read/write **`courts`**. |
| `categories_repository.dart` | Read/write **`categories`**. |

### Notifications (`notifications_repository.dart` + `notification_service.dart`)

| Idea | Plain effect |
|------|--------------|
| My inbox | **Fetch** **`notifications`** for me. |
| Mark read | **Update** one notification row. |
| “Tell user X something” | **Insert** row(s) into **`notifications`**; may also trigger **push** to phones. |

### Ball rental (`balls_repository.dart`)

| Idea | Plain effect |
|------|--------------|
| List balls | **Read** **`balls`**. |
| My active rentals | **Read** **`ball_rentals`** (with ball name). |
| Rent / return | **Call** server **`rent_ball`** / **`return_ball`** (not raw manual edits). |

### Schedule changes (`reservation_change_*`)

| Idea | Plain effect |
|------|--------------|
| Admin proposes new time | **Insert** **`reservation_change_requests`**; a **database trigger** may also create a **notification** row. |
| Player accepts/rejects | **Update** request + **update** **`reservations`** times/status following your rules. |

### Admin data (`admin_providers.dart`)

| Idea | Plain effect |
|------|--------------|
| Dashboard numbers | **Count** **`reservations`**, read **`analytics_daily`**. |
| Pending list | **Fetch** **`reservations`** where status is pending, **join** user/court names. |
| User list | **Fetch** **`users`**. |

### Push tokens (`push_notifications_service.dart`)

- Saves device tokens in **`user_push_tokens`** so the server knows **which phone** to ping.

---

## Part 7 — Server functions you can name in defense (RPC)

These are **pre-written procedures** on the database—like pressing a calculator key instead of redoing math by hand.

| Function name | Plain English |
|---------------|----------------|
| `get_occupied_slots` | “What times are already taken on this court and date?” |
| `check_reservation_overlap` | “Is this new slot free?” (When editing, can ignore the current booking’s ID.) |
| `calculate_booking_price` | “How much should this booking cost?” (day/night rates, duration.) |
| `rent_ball` | “Start a rental and mark the ball in use—safely.” |
| `return_ball` | “End the rental and free the ball—only if rules allow.” |

Exact spelling lives in `supabase/migrations/` SQL files.

---

## Part 8 — Models (`*_model.dart`)

**Plain English:** A **model** is the app’s **copy of one row’s fields**, with names adjusted for the programming language.

Example: database column `user_id` might appear as `userId` in code—that mapping happens in `fromMap`.

---

## Part 9 — Questions panelists ask (short answers you can say out loud)

**Where is a booking created?**  
After overlap and price checks, the app **inserts a row** into **`reservations`**. The main flow starts from the **home / player reservations** screen and goes through **`ReservationService`** and **`ReservationsRepository`**.

**How do you avoid double booking?**  
The server function **`check_reservation_overlap`** decides if the slot is still free. The UI also uses **`get_occupied_slots`** so users mostly pick valid times.

**Where do notifications come from?**  
Rows in **`notifications`**, often inserted by **`NotificationService`**. Change requests may also auto-create notifications via **database triggers**.

**What is Riverpod?**  
A way to **load data once** and **auto-refresh** the UI when data changes—less messy than passing data manually everywhere.

**What does the router do?**  
Chooses **which page** opens and **blocks** admin pages for non-admins.

**Where is Supabase configured?**  
When the app starts (`main.dart`), it connects to your Supabase project using URL + public key from settings (e.g. `env.dart`). **Never** put **secret** admin keys inside the public app.

**Why can only the borrower return a ball?**  
The **`return_ball`** function on the server checks that the rental’s **user** matches the logged-in user (see your SQL migration).

---

## Part 10 — Demo checklist (tie story to data)

1. Register → new row in **`users`**.  
2. Book → new row in **`reservations`** (pending).  
3. Try the same slot again → should **fail** overlap check.  
4. Admin approves → status changes; player sees update (Realtime).  
5. Notifications → rows in **`notifications`**.  
6. Ball rent/return → **`balls`** + **`ball_rentals`**.  
7. Receipt → file in **storage**, path on **`reservations`**.

---

## Part 11 — Other docs in this repo

| File | Use |
|------|-----|
| `docs/SYSTEM_DESIGN.md` | Bigger-picture design story. |
| `docs/FEATURES_GAP_CHECKLIST.md` | What’s fully done vs partial. |
| `docs/CAPSTONE_FLOWCHARTS.md` | Diagrams for thesis. |
| `docs/THESIS_DEFENSE_SCRIPT.md` | Speaking outline. |
| `supabase/migrations/*.sql` | **Official** list of tables, rules, and functions. |

---

## Part 12 — Mini glossary (kid-friendly)

| Word | Think of it as… |
|------|-------------------|
| **Widget** | One LEGO piece on screen (button, card, whole page). |
| **State** | What the screen is showing **right now** (loading, list, error). |
| **Repository** | The module that **only** handles save/load to the cloud tables. |
| **Service** | The module that **combines steps** (save + notify + refresh). |
| **Provider** | The helper that **feeds data** to the screen and **updates** when data changes. |
| **Table** | One **spreadsheet** in the database (`users`, `reservations`, …). |
| **RLS** | **Bouncer rules** at the door of each row: “only owner may read this.” |
| **JWT** | Short **visitor badge** proving you’re logged in for this session. |
| **RPC / function** | A **preset button** on the server (“run overlap check”) instead of DIY SQL from the phone. |
| **Realtime** | **Live refresh** when someone else changes data. |

---

## Last tip for defense

If someone points to a **file name**, use this **three-step trick**:

1. **Screen** — What does the user see? (Part 3–4.)  
2. **Repository** — Who saves to the database? (Part 6.)  
3. **Table** — Which **spreadsheet name**? (`users`, `reservations`, …)

If you know those three, you already sound like you **own** the project.

---

*Plain-language manual for CourtSide. Technical names are included so you can match what reviewers say—but your first explanation should always sound like Part 1.*
