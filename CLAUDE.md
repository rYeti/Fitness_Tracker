# ForgeForm — Project Memory

## Project overview
ForgeForm is a Flutter fitness app with an ASP.NET Core backend (JWT/OAuth/RBAC already in place). Two client surfaces: the trainee-facing tracker, and the **Trainer Console** — a trainer-facing companion for managing a client roster (chat, workout building, attendance/adherence, nutrition monitoring).

## Stack
- Backend: ASP.NET Core (C#), JWT/OAuth/RBAC, SignalR for real-time chat + notifications.
- Client: Flutter, targeting mobile (iOS/Android) **and** desktop (Windows/macOS/Linux) from one codebase.

## Key reference docs (read before implementing related features)
- `trainer-console-spec.md` — full Trainer Console feature spec, phasing, and competitive positioning.
- `design/trainer_console/design_handoff_trainer_console/README.md` — design handoff for the Trainer Console mockup. **Read this before touching any Trainer Console UI.**

## Design mockup handling — IMPORTANT
`design/trainer_console/design_handoff_trainer_console/Trainer Console.dc.html` is a **high-fidelity reference prototype, not production code**:
- It's built in a bespoke design-tool syntax (`<x-dc>` component, `DCLogic` class) that does not exist in this codebase — never copy/embed this markup directly.
- **Rebuild each screen using this repo's real Flutter widgets and state management**, following `lib/core/providers/theme_provider.dart` for design tokens (or the target framework's own conventions if building a separate web dashboard).
- Treat it as authoritative on layout, spacing, states, and interaction intent — but adapt freely to Flutter's actual constraints and whatever components/patterns already exist in this codebase. It is a reference, not a pixel-exact spec.
- Client names, numbers, and message content in the prototype are placeholder data — wire everything to real API responses.

## Design tokens (from the handoff — do not deviate)
- Brand accent: Forge Orange `#FF6B3E` (buttons, active states, progress fill, FAB)
- Neutrals: charcoal `#333` (app bar, both themes); light bg `#F5F5F5`/white cards; dark bg `#121212`, surface `#1E1E1E`, cards `#2C2C2C`
- Macro colors (fixed everywhere): protein red `#E53935`, carbs blue `#1E88E5`, fat green `#43A047`
- Status tones: ok = green, warn = amber, bad = red
- Radii: 8px buttons/inputs/tiles · 12px cards · 16px hero/summary cards · pill (999px) for progress bars/chips/FAB
- Typography: Montserrat (Bold/ExtraBold) for headings/stat numbers; Exo 2 for UI labels/body
- Icons: Material Symbols Rounded, outlined default, filled + orange when active

## Shared state — client-switcher
A single **active client** selection must live at the app-shell level and be shared across Roster, Chat, Workout Builder, and Nutrition — not re-selected per screen. Switching the active client re-derives all client-specific data in already-visible panes; it should not trigger a full navigation reload. See the design handoff README's "State Management" section for the exact state shape to replicate (`route`, `client`, `chatView`, `picker`, `layout`, builder new/edit mode, per-client data shape).

## Screens in scope
Dashboard (roster + KPIs), Client Detail, Messages/Chat (SignalR-backed), Workout Builder (create/edit modes, templates, day tabs, per-set tables), Nutrition (macro tracking, calorie ring, 7-day trend).

## Desktop support
The Trainer Console must run natively on desktop via Flutter's desktop targets, not just scale up from mobile:
- Responsive, breakpoint-driven layouts (e.g. a 3-pane desktop layout for Messages, collapsing to single-pane + bottom tabs on mobile).
- Shared active-client state must update all *simultaneously visible* panes on wide viewports, not just the current screen.
- Keyboard shortcuts and hover states are desktop-only affordances — gate behind platform checks, don't skip them.

## Working conventions
- Owner prefers to write implementation code himself — act as reviewer/guide, not code-provider, unless a skeleton is explicitly requested.
- Auth stack (JWT/OAuth/RBAC) already exists — reuse it for SignalR hub auth (token passed as `?access_token=` query param for the hub path, since WebSocket transport can't set headers).
- Tie SignalR group membership and any trainer-facing data access to `TrainerTraineeRelationship.Status == Active`, not role membership alone.
