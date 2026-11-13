# Redesign reference review

## Dashboard reference

The Home dashboard follows `cf9bce8d-ba0a-4cf0-b974-1cd528195221.jpeg`:

- Mountain sunset header, Orbit branding, greeting, search, notifications, ERP access, and profile.
- Today/Week/Month filters, a two-by-two summary grid, task-progress ring, shortcut bar, task cards, and five-item bottom navigation.
- Original WorkHub navy, orange, light surfaces, status colors, and Roboto typography are retained. Color constants in `OrbitColors`, `ErpColors`, and `WhatsAppColors` are unchanged from the original repository.
- Entrance fades, tab highlights, chart animation, and Android page transitions respect reduced-motion settings. Native iOS navigation is retained.

Task totals and status counts come from server pagination metadata for the selected due-date range. Dashboard filters have separate state from the Task Board. Unread totals are shown only when the API supplies complete pending items; otherwise the card shows unavailable. Points use the existing performance response. Sample counts, trend deltas, portrait, and historical comparisons from the reference are not fabricated.

The mountain background is a generated asset inspired by the reference, not the original photograph. The ERP tab opens the existing unified ERP Inbox. Profile images and tasks use live data. Task creation, EC progress, and field actions remain available in the task-options menu.

## Other screens

Inbox, Inbox Detail (including EC and logistics), Tasks, Task Detail, Projects, and project tasks now share Home's mountain header, rounded light surfaces, navy typography, spacing, and entrance motion. The common components are in `lib/core/widgets/orbit_workspace.dart`; Home uses the same surface implementation.

Original color constants and backend actions are retained. Detail sections stay mounted while scrolling so comment drafts and officer inputs remain available. Existing filters, pagination, completion/review actions, discussions, and project navigation are preserved. Header back navigation, narrow layouts, and larger text are covered by widget tests.

## Verification

Widget tests cover dashboard data, filters, task actions, EC progress, phone widths, and reduced motion. Phone-sized renders are inspected during implementation. Layout follows the supplied reference; literal pixel identity is not claimed because branding colors, live data, system chrome, display size, and the background photograph vary.

## Task Board reference

The Task Board follows `Gemini_Generated_Image_qw91deqw91deqw91.jpeg`: a persistent search pill, tune button, Today/This Week/Month/Overdue tabs, a single frosted task list, priority/status badges, assignee/date/attachment metadata, and a circular create button. Advanced filters, saved priorities, and EC ideas remain mounted behind the tune button so their input state is retained.

Quick periods query the existing server filters; Overdue and View All explicitly clear obsolete date bounds. Pending-review tasks remain active even at 100% progress. Checkboxes and task menus use the server-provided completion/review capability. Names, avatars, titles, and counts remain live.
