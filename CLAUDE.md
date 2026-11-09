# Sumi Md

Lightweight, native macOS Markdown editor (SwiftUI + AppKit). Read `PLAN.md` for scope,
architecture and milestones. This file is what to know before changing code.

## Layout
- `SumiMD/SumiMD.xcodeproj`: Xcode project (newer text-based `project.xcproj` format)
- `SumiMD/SumiMD/`: app sources. This folder is synced with the target, so **new files
  here are picked up automatically; do not edit the project file to add or remove sources**.
- `PLAN.md`: product scope and milestones. `README.md`: public description.

## Build and run
```
xcodebuild -project SumiMD/SumiMD.xcodeproj -scheme SumiMD -destination 'platform=macOS' build
```
- Confirm the scheme name with `xcodebuild -list -project SumiMD/SumiMD.xcodeproj` if the build says it is missing.
- After any code change, build and fix compile errors before reporting the work as done.
- Add tests in a unit-test target once Markdown parsing/styling exists, and run them with
  `xcodebuild ... test`.

## Project rules
- macOS only. Deployment target is macOS 26.6.2 (decided; do not lower without asking).
- Native only: SwiftUI + AppKit. No Electron, no web editor frameworks.
- Files are plain `.md`. The editor must keep the text **exactly as typed** (no smart quotes,
  no rewriting). Styling is done with text attributes, never by changing the string.
- Editor = `NSTextView` (TextKit 2) wrapped in `MarkdownTextView`. Rendered view = `WKWebView`
  fed by the same parser (`swift-markdown`). One parser for both.
- Restyle only the edited paragraph range, not the whole document (large-file performance).
- Keep it light: no notes library, sync, plugins or wiki-links (see "Out of Scope" in PLAN.md).
- Keep the app sandbox-ready. User-selected files must stay read-write.
- Project uses default MainActor isolation. Mark the document model `nonisolated`.

## Naming
- Repo `sumi-md`; Xcode project/target `SumiMD`; user-facing name "Sumi Md".

## Git
- One repo at the project root. Branch per milestone, small commits, clear messages.
- Never force-push. Pushing is done only when the user asks.
- Do not commit `xcuserdata/`, `DerivedData/` or `.DS_Store` (covered by `.gitignore`).

## Current state
Milestone 1 (skeleton) is done. Milestone 2 (styling) in progress on `milestone-2-styling`:
- `MarkdownSourceMap`: swift-markdown line/UTF-8 column -> UTF-16 offsets (emoji/Hebrew safe).
- `MarkdownStyler` / `MarkdownParse`: parse tree -> `StyledSpan`s (semantic styles, marker ranges).
- `MarkdownHighlighter`: reparses on each edit, restyles only the dirty region (blocks around
  the edit, extended until block layout matches the previous parse).
- `MarkdownTheme`: styles -> fonts/colors (system colors, dark mode safe).
- `MarkdownTextView.Coordinator` restyles from `NSTextStorageDelegate.didProcessEditing`.
- Tests in `SumiMD/SumiMDTests` (Swift Testing). Run with `xcodebuild ... test`.
- Known: a keystroke in a 430 KB file costs ~76 ms (Release), mostly the full reparse.
  Revisit in Milestone 4 (parse only a window around the edit).
- Project-file edits: use `xcrun xcodeproj` (targets, packages, settings), never hand-edit.

## Notes
- If `xcodebuild` says it needs Xcode, the active developer dir is Command Line Tools: prefix
  commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- At launch the app shows the standard open panel (New Document / pick a file). That is normal.
- "Unable to obtain a task name port right", "ViewBridge ... Terminated" and similar console
  lines from the debugger or open/save panels are system noise, not app errors.

## Open decisions
- `.md` document/imported type is declared in `SumiMD/Info.plist` (merged into the generated plist via `INFOPLIST_FILE`). Keep it outside the synced `SumiMD/SumiMD/` folder.
- Distribution (App Store vs direct), pricing, domain: see PLAN.md.
