# P10 — Issue untuk `celineemercy/space-sync`

Hasil review aplikasi rekan (React Native/Expo + NestJS, branch `dev`).
Total **12 issue**: **7 bug** + **5 fitur**. Setiap entri sudah siap dipaste ke
GitHub Issues (judul + body). Nomor baris mengacu ke branch `dev`.

Cara pakai: buka `https://github.com/celineemercy/space-sync/issues/new`, paste
judul & body, tambahkan label `bug` atau `enhancement`.

---

## BUG 1 — Saving the same room twice crashes with a raw SQLite error

**File:** `mobile/src/features/saved-rooms/storage.ts`

**Problem**
`saved_rooms.room_id` is declared `TEXT UNIQUE NOT NULL`, but `insertSavedRoom`
inserts without checking whether the room is already saved:

```ts
await database.runAsync(
  `INSERT INTO saved_rooms (...) VALUES (?, ...)`, ...
);
```

A second save of the same room throws `UNIQUE constraint failed:
saved_rooms.room_id` straight from the driver. The web implementation
(`storage.web.ts`) *does* guard with
`savedRooms.some((item) => item.roomId === room.id)`, so the two platforms
behave differently.

**Reproduce**
1. Open a room → "Save room locally".
2. Go back, open the same room, tap save again (e.g. after the query cache was
   cleared).
3. Raw SQLite error appears instead of a friendly message.

**Expected**
Idempotent save, or a clear message ("Room is already saved.").

**Suggested fix**
Check for an existing row (or use `INSERT ... ON CONFLICT(room_id) DO UPDATE`)
and throw the same `Error("Room is already saved.")` the web build uses.

---

## BUG 2 — Saved rooms leak between accounts on a shared device

**File:** `mobile/src/features/saved-rooms/storage.ts`,
`mobile/src/providers/auth-provider.tsx`

**Problem**
The `saved_rooms` table has no `user_id` column, so it is device-wide. `signOut`
clears the session, the query cache, reminders and cached *reservations*:

```ts
queryClient.clear();
await clearSession();
try { await clearReminders(); } catch {}
if (userId) await clearCachedReservations(userId);
```

…but nothing clears `saved_rooms`. The next student who signs in on the same
device sees the previous student's saved rooms **and their personal notes**.

**Reproduce**
1. Sign in as student A, save two rooms with notes.
2. Sign out, sign in as student B.
3. Open the Saved tab → A's rooms and notes are still listed.

**Expected**
Saved rooms are per-user, and a different account starts with an empty list.

**Suggested fix**
Add a `user_id` column (and include it in the primary key / `WHERE` clause), or
call a new `clearSavedRooms()` from `signOut` alongside
`clearCachedReservations`.

---

## BUG 3 — Reservation status labels freeze for the whole session

**File:** `mobile/src/app/(app)/(tabs)/reservations.tsx`

**Problem**
`now` is captured once and never updated:

```ts
const [now] = useState(() => Date.now());
```

Every grouping and label depends on it:

```ts
const confirmed = reservations.filter((item) =>
  item.status === "CONFIRMED" && new Date(item.endsAt).getTime() > now);
...
if (reservation.status === "CONFIRMED")
  return new Date(reservation.endsAt).getTime() <= now ? "Completed" : "Approved";
```

If the app stays open across a reservation's `endsAt`, the card keeps showing
"Approved" and stays under "Upcoming" indefinitely. Only a full remount fixes it.

**Reproduce**
1. Sign in and open Reservations.
2. Leave the app open until a confirmed reservation's end time passes.
3. The card still says "Approved" and is still under "Upcoming".

**Expected**
Labels and sections re-evaluate as time passes.

**Suggested fix**
Tick `now` on an interval (e.g. `setInterval` every 60 s) or derive it from a
`useSyncExternalStore`-based clock, and clean up on unmount.

---

## BUG 4 — Booking failure shows no error because the modal covers it

**File:** `mobile/src/app/(app)/room/[id].tsx`

**Problem**
`reservation.error` is rendered inside the booking card:

```tsx
{reservation.error ? <StatusMessage error={reservation.error} /> : null}
```

But the request is submitted from `ConfirmationDialog`, which stays open on
failure (`setDialog("success")` only runs on success). The dialog is an overlay,
so the error message is rendered *behind* it. The user sees a dialog that
appears to do nothing.

**Reproduce**
1. Pick a slot, attach a document, tap "Book room" → "Submit request".
2. Make the request fail (stop the API, or book a slot that was just taken).
3. The dialog stays open with no visible error.

**Expected**
The failure is visible where the user is looking — inside the dialog.

**Suggested fix**
Pass `error={reservation.error}` into `ConfirmationDialog` (or close the dialog
and surface the error on the card). Also reset `reservation` before reopening.

---

## BUG 5 — Pending requests expire at their start time, so admins can never approve them

**File:** `server/src/reservations/reservations.service.ts`

**Problem**

```ts
private async expirePending() {
  await this.prisma.reservation.updateMany({
    where: { status: ReservationStatus.PENDING, startsAt: { lte: new Date() } },
    data: { status: ReservationStatus.EXPIRED, decidedAt: new Date() },
  });
}
```

`expirePending` runs on module init and every 60 s. Meanwhile `decide` requires
`startsAt: { gt: now }`:

```ts
where: { id, status: ReservationStatus.PENDING, startsAt: { gt: now } }
```

So a request whose start time has arrived is auto-expired, and any admin action
at that moment fails with `REQUEST_ALREADY_DECIDED` ("This request is no longer
pending") — even though the room is still usable until `endsAt`. Students who
book close to the slot start lose their request before an admin can look at it.

**Reproduce**
1. Create a reservation starting in ~2 minutes.
2. Wait until the start time passes without approving it.
3. The request is `EXPIRED`; approving it returns `REQUEST_ALREADY_DECIDED`.

**Expected**
A pending request stays actionable for the duration of its window, or expires
at `endsAt`, not at `startsAt`.

**Suggested fix**
Use `endsAt: { lte: new Date() }` in `expirePending`, and keep the `decide`
guard consistent with whatever bound is chosen.

---

## BUG 6 — Availability check ignores pending requests whose start time has passed

**File:** `server/src/availability/availability.service.ts`

**Problem**

```ts
reservations: {
  none: {
    OR: [
      { status: ReservationStatus.CONFIRMED },
      { status: ReservationStatus.PENDING, startsAt: { gt: new Date() } },
    ],
    startsAt: { lt: endsAt },
    endsAt: { gt: startsAt },
  },
},
```

The `startsAt: { gt: new Date() }` clause excludes pending reservations that
have already begun. Between the moment a slot starts and the 60-second
`expirePending` sweep (BUG 5), a still-`PENDING` reservation stops blocking the
room, so a second student can request an overlapping slot. The same filter is
duplicated in `reservations.service.ts::create`, so the write path has the same
hole.

**Reproduce**
1. Student A requests 10:00–11:00 (stays `PENDING`).
2. At 10:00:30, before the maintenance sweep runs, student B searches 10:00–11:00.
3. The room is returned as available and B's request is accepted.

**Expected**
Pending requests block their slot until they are decided, expired, or
cancelled — not until they start.

**Suggested fix**
Drop the `startsAt: { gt: new Date() }` condition, or replace it with
`endsAt: { gt: new Date() }` so only genuinely finished requests stop blocking.
Extract the shared `where` fragment so the read and write paths cannot drift.

---

## BUG 7 — Booking times are built in device-local time but displayed in Jakarta time

**File:** `mobile/src/lib/date-time.ts`

**Problem**

```ts
export function combineDateAndTime(date: Date, time: Date): Date {
  const result = new Date(date);
  result.setHours(time.getHours(), time.getMinutes(), 0, 0);
  return result;
}
```

`setHours` uses the **device** timezone, while every label goes through
`toCampusLabel`, which formats in `Asia/Jakarta`:

```ts
new Intl.DateTimeFormat("en-ID", { ..., timeZone: "Asia/Jakarta" })
```

On a device set to, say, `Asia/Makassar` (WITA), a student who picks 09:00 gets
a reservation stored at 09:00 WITA and displayed back as **08:00** — and the
server stores the shifted instant, so the room is actually held for the wrong
hour.

**Reproduce**
1. Set the device timezone to anything other than `Asia/Jakarta`.
2. Search for a room and pick 09:00–11:00.
3. Open the room detail / reservation card: the label shows a different hour
   than the one picked.

**Expected**
The wall-clock time the student picks is the campus wall-clock time.

**Suggested fix**
Build the instant in the campus timezone (e.g. `Temporal.ZonedDateTime` or a
small offset helper), or format with the same timezone used for input. Add a
test that pins `TZ` to a non-Jakarta zone.

---

## FEATURE 1 — Add runtime logging and a global error handler

**Problem**
There is no structured logging. Errors are swallowed in several places
(`catch { /* ... */ }` in `room/[id].tsx`, `reservations.tsx`,
`auth-provider.tsx`), and uncaught errors in release builds leave no trace, so
bugs that only happen while the app is running are very hard to diagnose.

**Proposal**
- A tiny `logger` module (`info` / `warn` / `error`) that is a no-op in
  production or forwards to a sink.
- `ErrorUtils.setGlobalHandler` (React Native) for uncaught JS errors.
- Log every API request: method, path, status, duration, and error code.
- Log navigation transitions so the screen sequence can be reconstructed.

**Acceptance**
A failed booking produces a log line with the endpoint, status code, and
`ApiClientError.code`.

---

## FEATURE 2 — Show a visible error inside the confirmation dialog

**Problem**
Every mutation (`useCreateReservation`, `useCancelReservation`,
`useUpdateSavedRoom`, `useDeleteSavedRoom`) renders its error on the screen
underneath the `ConfirmationDialog`. See BUG 4 — the pattern is used in four
places, so it should be fixed once in the shared component.

**Proposal**
Add an optional `error?: Error | null` prop to `ConfirmationDialog` and render
`StatusMessage` above the action buttons. Keep the dialog open on failure.

**Acceptance**
A failed cancel shows the error inside the open dialog, and the dialog stays
open so the user can retry.

---

## FEATURE 3 — Cache rooms and availability for offline use

**Problem**
`docs/local-data-persistence.md` promises an offline-first experience, and
reservations *are* cached (`cached_reservations` + `loadReservations` returning
`stale: true`). But rooms and availability are not: `useRooms` / `useRoom` /
`useAvailabilitySearch` all fail hard when the network is down, so the Search
tab is unusable offline even though `cached_rooms` and `cached_facilities`
tables already exist in `storage/database.ts`.

**Proposal**
- Serve `useRooms` / `useRoom` from `getCachedRooms()` when the request fails,
  with the same `stale` banner used by the reservations screen.
- Cache the last availability result per query key.

**Acceptance**
With the API stopped, the room list and a previously opened room detail still
render, with an "offline, last updated …" banner.

---

## FEATURE 4 — Add search, sort and note filtering to Saved rooms

**Problem**
The Saved tab renders every saved room in `updated_at DESC` order with no way to
find one. A student with 15 saved rooms has to scroll and read each card.

**Proposal**
- A search field matching room code, name, location and note.
- A sort toggle (recently updated / code / capacity).
- Show a result count and reuse the existing empty state.

**Acceptance**
Typing "lab" filters the list to rooms whose code, name, location or note
contains "lab".

---

## FEATURE 5 — Add accessibility labels to status text and the camera frame

**Problem**
Several pieces of information are conveyed by colour and bare `Text` only:

- `statusLabel()` output is coloured (`styles.pending` / `styles.rejected`)
  but has no `accessibilityLabel`, so a screen reader reads "Approved" with no
  context about which room.
- The QR `CameraView` has no accessible description; a blind user gets an
  unlabelled view.
- The `chips` list of facilities is a flat run of `Text` nodes.

**Proposal**
- Wrap each reservation card in a single `accessibilityLabel` summarising room,
  time and status.
- Add `accessibilityLabel` / `accessibilityHint` to the camera frame
  ("Camera viewfinder. Point at a room QR code.").
- Group the facilities chips into one accessible node.

**Acceptance**
TalkBack/VoiceOver reads "Room LAB-301, 10 November 09:00, Approved" as one
item instead of three fragments.

---

## Ringkasan

| # | Jenis | Judul singkat | File utama |
|---|---|---|---|
| 1 | bug | Duplicate saved room → raw SQLite error | `saved-rooms/storage.ts` |
| 2 | bug | Saved rooms leak antar akun | `saved-rooms/storage.ts`, `auth-provider.tsx` |
| 3 | bug | Status reservasi beku (`now` sekali) | `(tabs)/reservations.tsx` |
| 4 | bug | Error booking tertutup modal | `room/[id].tsx` |
| 5 | bug | PENDING expire di `startsAt` → admin tak bisa approve | `reservations.service.ts` |
| 6 | bug | Pending yang sudah mulai tidak memblokir slot | `availability.service.ts` |
| 7 | bug | Jam booking pakai zona waktu perangkat | `lib/date-time.ts` |
| 8 | fitur | Runtime logging + global error handler | baru |
| 9 | fitur | Error di dalam `ConfirmationDialog` | `components/ui/confirmation-dialog.tsx` |
| 10 | fitur | Cache rooms & availability untuk offline | `features/rooms/queries.ts` |
| 11 | fitur | Search/sort di Saved rooms | `(tabs)/saved.tsx` |
| 12 | fitur | Accessibility label status & kamera | `(tabs)/reservations.tsx`, `scan.tsx` |
