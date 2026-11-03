# ret_ImmersiveScreen

World of Warcraft addon for Retail and Forever: one key hides the interface and all names
and adds Letterbox bars. Read `docs/VISION.md` before proposing or building features:
it defines the scope of the next version and records decisions. `docs/ROADMAP.md`
shows where the project stands and what comes next.

## Repository layout

- `ret_ImmersiveScreen/` — the addon exactly as it ships. Only game files go here.
- `docs/` — planning and development documents.
- The previous, deprecated addon is https://github.com/retRodya/ret_Cinemator.
  Mine it for knowledge (API quirks, past bugs), not for code.
- `CHANGELOG.md` — user-visible changes, Keep a Changelog format.

## Language

- Talk to the user in Russian. The user is learning to run a project: briefly
  explain the reasoning behind process and architecture choices.
- Code, comments, addon UI text, commit messages, CHANGELOG and README are English.
- Documents in `docs/` are Russian.

## Scope

- Build only what VISION.md lists for the current version. For anything else,
  suggest a GitHub issue instead of implementing it.
- New decisions go to the decision log in VISION.md. Committed rows are never
  rewritten; a new row supersedes an old one.

## Code

- One codebase for Retail and Forever. Guard APIs that differ between clients
  (`C_AddOns and C_AddOns.X or X`).
- Small files, one Effect per module. A disabled Effect creates no frames,
  registers no events and runs no OnUpdate.
- Event-driven only: no polling, no timers that re-check state.
- Anything that changes game state (UI visibility, CVars) restores it on exit,
  `/reload`, logout and after a client crash.
- Use native Blizzard UI: Settings API, key bindings, fonts and tooltip styles.

## Workflow

- One focused change per commit, Conventional Commits (`feat:`, `fix:`, `docs:`,
  `refactor:`, `chore:`).
- Add user-visible changes to `[Unreleased]` in CHANGELOG.md in the same commit.
- `## Version` in the TOC follows SemVer and changes only at release time.
- Claude cannot run the game: after a change, list what the user should check in-game.
- Commit and push only when the user asks.
