# Following several swaps at once

Plan for this PR, stacked on #706. Nothing below is implemented yet.

## Why

The wallet follows one swap: an `ActiveSwap` in a single SharedPreferences
slot, one notifier, one poll timer, and a home Swap button that either starts
a swap or opens the one being followed. Starting a second swap replaces the
first, whose deposit address is then forgotten. Now that running swaps show as
rows above the home activity (#706), there is room to follow several. The
alternative, refusing a new swap while one runs, would block users for hours
on slow chains such as Bitcoin.

## What stays

- `ActiveSwap` and `SwapOrder` as the record of one swap. 1Click identifies a
  swap by its deposit address (and memo), which the record already holds.
- Polling by deposit address every 5 s through `SwapService.getSwapStatus`,
  and the merge that keeps "I've Sent It" across a poll in flight.
- The deposit, progress, complete and failed screens; the overdue rule and
  Stop tracking.
- No settled swaps in the history: the indexer cannot rebuild them.

## Design

### Identity

`ActiveSwap.id` is the deposit address, with the memo appended when there is
one (`address` or `address#memo`). 1Click never hands out the same deposit
address twice.

### Storage (quantus_sdk `SettingsService`)

- One key, `active_swaps`: a JSON list of `ActiveSwap`, in order of starting.
- `getActiveSwaps()`, `saveActiveSwap(swap)` (upsert by id), `removeActiveSwap(id)`,
  `clearActiveSwaps()` for logout.
- On the first read, a record under the old `active_swap` key moves into the
  list and the key is removed, so a swap in flight survives the update.

### State (`ActiveSwapsNotifier extends Notifier<List<ActiveSwap>>`)

- `start(swap, ticket)` adds or replaces by id; `remove(id)` is today's
  `clear`; `markDepositSent(id)`; `refresh(id)`.
- Tickets: `ticket()` hands out a token and remembers it; `start` with a token
  no longer remembered is refused, as today for a deposit that lands after a
  logout. Only `clearAll()` (logout) forgets tokens, so removing one swap no
  longer invalidates another's deposit in flight.
- Polling: one timer every 5 s polls, in sequence, every swap that is neither
  final nor simulated; each answer merges into that swap's latest record by
  id, and an answer for a swap removed meanwhile is dropped. One timer and a
  loop, rather than a timer per swap.
- `swapClockProvider` emits `clock.now()` once a second while any swap is
  unsettled; rows and screens derive elapsed time from it. Replaces
  `swapElapsedProvider`.
- `activeSwapProvider(id)` selects one swap for its screen.

### Screens

- `SwapProgressScreen(id, account)` reads its swap by id and keeps the last
  record on screen while the route leaves after removal, as today. Done, Start
  a New Swap, back on a failed swap and Stop tracking call `remove(id)`.
- `ReviewSwapScreen` takes its ticket from the new notifier and pushes the
  progress screen with the new swap's id. Otherwise unchanged.
- Deposit screen: leaving it before "I've Sent It" removes the swap. A
  half-started swap is not kept; funds sent to that address later are still
  swapped by 1Click and arrive at the account on their own.
- Home Swap button: opens the form whenever the account can swap. It no
  longer opens a followed swap; the rows do.

### Rows

- One row per followed swap, newest first, in the regular and multisig
  activity sections, masked under hide-balances like the feed.
- Running and overdue swaps as in #706. Settled swaps keep a row until the
  user has seen them: "Swap complete" with sage dots, "Swap failed" with
  ember dots, each opening its screen, where Done or back puts it away. With
  the button no longer opening followed swaps, this is the only way to reach
  a result. The alternative, dropping a swap the moment it settles with a
  toast, loses the result if the toast is missed.
- An unsent hand deposit has no row; it is removed when its screen is left.

### Limits

- At most 10 followed swaps. Starting one more removes the oldest settled
  swap; if none is settled, the form refuses with a toast.
- No automatic expiry beyond the overdue rule.

## Steps

Each step is a commit with its tests.

1. SDK: `ActiveSwap.id`; `SettingsService` list storage and migration.
   Tests in `settings_service_test`.
2. Notifier: list state, tickets, one-timer polling, clock provider; logout
   clears all. A new `active_swaps_provider_test`, with the 1Click test
   double from `swap_flow_test` moved into `test/fakes.dart`.
3. Screens by id; removal on leaving the deposit screen; review start.
   `swap_flow_test`.
4. Home: button opens the form; rows for every followed swap including
   settled ones; harness rows start several swaps and clear them all.
   `home_intent_gating_test`.
5. Fold this plan into `near-intents-swaps.md` and delete this file.

## Risks

- Migration of a swap in flight across the update: a read-once move, with a
  test on a saved old record.
- Poll volume grows with the number of swaps; the cap bounds it.
- Tickets are the only subtle part; a remembered set of tokens is simpler
  than today's generation counter and the behaviour on logout stays the same.

Roughly 600 lines change across the SDK, providers, screens and tests.
