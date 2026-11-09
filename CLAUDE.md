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
Milestone 1 (skeleton): `MarkdownDocument` (open/save `.md`), `MarkdownTextView` (plain-text
editor), `DocumentGroup` app. These files were written without being compiled.

## First tasks for a local session
1. `SumiMD/.git` is a stray repo Xcode created (one template commit). Confirm with
   `git -C SumiMD log --oneline`, then remove `SumiMD/.git` so the root repo tracks the project.
2. Rename `SumiMD/SumiMD/MyApp.swift` to `SumiMDApp.swift` (it contains `SumiMDApp`).
3. Build, fix any compile errors, then verify open/edit/save of a `.md` file manually.
4. Commit and push (with the user's go-ahead).

## Open decisions
- Deployment target is macOS 26.6.2 (Xcode default); PLAN.md assumes 14. Ask before changing.
- Project still lists iOS/visionOS destinations; the AppKit code is macOS-only.
- `.md` document/imported type is declared in `SumiMD/Info.plist` (merged into the generated plist via `INFOPLIST_FILE`). Keep it outside the synced `SumiMD/SumiMD/` folder.
- Distribution (App Store vs direct), pricing, domain: see PLAN.md.
