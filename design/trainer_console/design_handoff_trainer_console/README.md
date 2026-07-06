# Handoff: ForgeForm Trainer Console

## Overview
A trainer-facing companion surface for the ForgeForm fitness app. It lets a trainer manage their whole client roster from one place: chat with a client, build and assign structured workout plans (exercises/sets/reps/weight/RPE by day), track attendance/adherence over time, and monitor daily nutrition/macros. A client-switcher keeps the same selected client in sync across Chat, Workout Builder, and Nutrition.

## About the Design Files
The file in this bundle (`Trainer Console.dc.html`) is a **design reference built in HTML** — a high-fidelity, click-through prototype showing intended layout, states, and interactions. It is not production code to copy directly. It renders as a single custom `<x-dc>` component using a lightweight in-house template runtime + a `Component extends DCLogic` class (a bespoke authoring format for this design tool) — that syntax will not exist in your codebase.

**The task is to recreate this design in the app's real environment** — the ForgeForm Flutter app's own screens/widgets (`lib/feature/**`, following `lib/core/providers/theme_provider.dart` for tokens), or, for a web trainer dashboard, whatever framework the target codebase already uses. Rebuild it with that codebase's existing components, state management, and data layer — do not embed or ship this HTML.

## Fidelity
**High-fidelity.** Colors, type, spacing, and component choices are final and pulled directly from the bound ForgeForm design system tokens (see Design Tokens below). Copy/labels shown are representative examples, not final CMS content — treat exact client names/numbers as placeholder data to wire to real API responses.

## Screens / Views
The prototype has two device modes (Desktop and Mobile — toggle in the floating control, bottom-right of the preview) and a light/dark theme toggle. Each screen below exists in both device modes unless noted.

### 1. Dashboard
**Purpose:** Trainer's home base — roster overview and KPIs.
**Layout:** Desktop: fixed 240px charcoal sidebar (logo, nav: Dashboard/Messages/Workout Builder/Nutrition, Schedule/Settings at bottom) + fluid main content area with 32px padding. Mobile: content fills viewport under a charcoal app bar, bottom tab bar (Dashboard / Workouts / Messages / Nutrition) replaces the sidebar.
**Components:**
- KPI row: 3–4 stat tiles (active clients, avg adherence, sessions this week, alerts), each an icon tile (12%-tint color square + glyph) + Montserrat bold number + Exo 2 label, in a card (12px radius, 0.5px hairline border, soft shadow).
- Roster: grid/table view toggle (segmented control). Grid = client cards (avatar initials in colored circle, name, program tag, adherence %, status badge). Table = dense rows with sortable columns (name, program, adherence, last session, status).
- Status badges: 3 tones — `ok` (green bg/text), `warn` (amber), `bad` (red) — used for adherence/attendance state.
- Clicking a roster row/card opens Client Detail (see below).

### 2. Client Detail
**Purpose:** Deep dive on one client's progress.
**Layout:** Header with back arrow + avatar + name + status. Below: a responsive grid of cards — adherence, weight trend (line/bar chart), attendance (per-week bar chart), and a macro summary strip.
**Components:** Reuses `StatTile`, `ProgressBar`, `MacroSummary` design-system components. Weight/attendance charts are hand-built inline SVG/CSS bars (see file for exact markup) — no charting library.
**Note:** this screen currently shows a fixed profile (not yet wired to the client-switcher used elsewhere); wire it to the same shared `clients` list.

### 3. Messages (Chat)
**Purpose:** Direct messaging with clients; assign workouts from within a thread.
**Layout — Desktop:** 3-column layout inside one card: conversation list (300px) — thread (fluid) — client context panel (260px). **Mobile:** conversation list is its own screen; tapping a row drills into a full-screen thread with a back arrow; a composer bar pins to the bottom (bottom-nav hides while a thread is open).
**Components:**
- Conversation row: avatar (initials, colored per-client), name, timestamp, message preview (truncated), unread dot. Selected row gets a left orange border + tinted background (desktop).
- Thread: date divider, chat bubbles (mine = orange fill/white text, right-aligned; theirs = card-colored, left-aligned; both `border-radius: 4px 14px 14px 14px` / mirrored), an inline "workout card" bubble type (icon + title + subtitle) for shared plans, composer with add-attachment icon + pill input + circular orange send FAB.
- Context panel (desktop only): large avatar, name, program, 2 quick stats (adherence %, week progress).
- **Data model:** 5 example clients, each with a full message thread, program info, and nutrition numbers — see `clients` array in the logic class for the exact shape to replicate server-side.

### 4. Workout Builder
**Purpose:** Create and edit workout plans, assign to a client.
**Layout:** Header row: plan title + edit icon, client-switcher chip (opens a dropdown/sheet listing all clients), Save + "Assign to client" buttons, and a **"+ New workout"** button that opens the create flow instead of editing the current plan.
**States:**
- **Create (`isBuilderNew`):** name field, client picker, and a "start from a template" list (icon + name + meta, e.g. "Push / Pull / Legs — 4 days · Hypertrophy").
- **Edit (`isBuilderEdit`):** day tabs (Push A / Pull A / Legs / Rest — horizontally scrollable on mobile), each day shows its exercises as cards: icon tile (colored by muscle group), exercise name + muscle + rest time, a set-by-set table (SET / REPS / WEIGHT / RPE columns), current/top set highlighted in orange, "+ Add set" and "+ Add exercise" actions.
**Components:** Uses design-system `Button` for Save/Assign; everything else is custom card/table markup (see file — this is a genuinely new desktop pattern not in the base app, built in-brand).

### 5. Nutrition
**Purpose:** Monitor a client's daily intake and week-over-week trend.
**Layout:** Header with client-switcher chip (same pattern as Builder). Below: a calorie-ring card (SVG ring, kcal consumed / goal, remaining/over pill, macro summary bar), a "Today's meals" list (breakfast/lunch/snack/dinner rows with icon, description, kcal — unlogged meals shown at 50% opacity), and a 7-day "calories vs. target" bar chart (each bar colored by macro-mix, red if over budget that day).
**Components:** `MacroSummary` (design-system) for the P/C/F bar; ring + trend chart are custom inline SVG/CSS.

## Interactions & Behavior
- **Client-switcher** (Builder, Nutrition, Chat): a chip button toggles a dropdown/sheet listing all clients (avatar, name, program, checkmark on the active one). Selecting one updates `state.client` — a single shared index — which re-derives all client-specific data (`sel` object) used across those three screens. This is the core piece of shared state; replicate it as a single "active client" selection at the app-shell level, not per-screen.
- **Chat drill-in (mobile only):** list → thread is a `chatView` state (`'list' | 'thread'`) layered on top of the client selection; opening a thread sets both the active client and `chatView = 'thread'`; back arrow returns to `'list'` if in a thread, or to Dashboard if already in the list.
- **New workout vs. edit:** `isBuilderNew` / `isBuilderEdit` are mutually exclusive states in the Builder; the "+ New" button and template-list rows switch into edit mode with a chosen template.
- **Nav:** left sidebar (desktop) / bottom tabs (mobile) switch top-level `route` (`dashboard | client | messages | builder | nutrition`). Active states: sidebar item gets tinted background + orange text/icon; bottom tab icon fills solid and turns orange.
- **Device + theme toggles:** floating control (bottom-right) swaps `surface` (`desktop | mobile`) and `theme` (`light | dark`) — these are prototype-only aids to preview both breakpoints/themes in one file; a real app doesn't need this control, just the two responsive layouts and a theme setting.
- **Animations:** none beyond the design system's standard press/hover states (subtle darken or ~0.97 scale) — no custom transitions were added.

## State Management
Minimum state needed to reproduce:
- `route`: current top-level screen.
- `surface`: `desktop | mobile` (prototype-only; real app picks by viewport).
- `theme`: `light | dark`.
- `client`: index/id of the currently active client (shared across Chat, Builder, Nutrition, Roster).
- `chatView`: `list | thread` (mobile chat only).
- `picker`: whether the client-switcher dropdown is open.
- `layout`: roster `grid | table` toggle.
- `builderNew` / edit-vs-create mode for the Workout Builder.
- Per-client data (see `clients` array in the file): name, avatar initials, program label, plan name/days/focus tag, adherence %, week progress, weight, status + status tone, chat thread (array of `{who, text, time}` or `{who:'card', title, sub}` messages), and nutrition (`kcal, goal, protein, carbs, fat, avg, overNote`).

## Design Tokens
Pulled from the bound ForgeForm design system — do not deviate:
- **Brand accent:** Forge Orange `#FF6B3E` — primary buttons, active states, progress fill, FAB.
- **Neutrals:** charcoal `#333` (app bar, always charcoal in both themes); light bg `#F5F5F5` / white cards; dark bg `#121212`, surface `#1E1E1E`, cards `#2C2C2C`.
- **Macro colors (fixed everywhere):** protein red `#E53935`, carbs blue `#1E88E5`, fat green `#43A047`.
- **Status tones:** ok = green tint/text, warn = amber, bad = red (see `STATUS` map in the logic class for exact rgba values).
- **Radii:** 8px buttons/inputs/icon tiles · 12px cards · 16px hero/summary cards · pill (999px) for progress bars, chips, FAB.
- **Cards:** 0.5px hairline border (~10% ink) + soft shadow (Material elevation 2; raised = elevation 4).
- **Typography:** Montserrat (Bold/ExtraBold) for wordmark, headings, stat numbers; Exo 2 for UI labels/body/buttons.
- **Icons:** Material Symbols Rounded, outlined by default, filled + orange when active (e.g. active bottom-nav tab).
- Full token values: `tokens/colors.css`, `tokens/typography.css`, `tokens/spacing.css`, `tokens/fonts.css` in the design system bundle.

## Assets
- Design-system bundle: `_ds_bundle.js` + `styles.css` + token CSS files (colors/typography/spacing/fonts) — source of truth for all values above.
- Design-system components used: `Button`, `MacroSummary` (from `components/core/` and `components/fitness/`).
- Icons: Google Fonts "Material Symbols Rounded" (loaded via `<link>` in `<helmet>`), referenced by ligature name (e.g. `fitness_center`, `forum`, `nutrition`).
- No custom images/photography — the design is intentionally data/UI only, per brand guidelines (no stock photography, no gradients/textures).

## Files
- `Trainer Console.dc.html` — the full prototype (all 5 screens, both device modes, both themes, in one file). Open directly in a browser to click through it.
