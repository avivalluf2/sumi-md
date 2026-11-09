# Sumi Md

*Repository: `sumi-md`*

A lightweight, native macOS Markdown editor.

- Opens `.md` files instantly
- Styled plain-text editing: headings, bold, and code look right while you type
- Press Cmd+E to flip to a clean rendered view
- GitHub-flavored Markdown: tables, task lists, strikethrough
- Light and dark mode
- No library, no sync, no plugins

## Status
Milestone 1 (skeleton) done: open, edit and save `.md` files in a plain-text editor.
Styling, the rendered view and preferences are next. See [PLAN.md](PLAN.md) for scope, architecture, and milestones.

## Building
Requires Xcode. Open `SumiMD/SumiMD.xcodeproj`, choose the **My Mac** destination, and run.

## Project layout
- `SumiMD/SumiMD.xcodeproj`: Xcode project
- `SumiMD/SumiMD/`: app sources (Xcode picks up files in this folder automatically)
  - `SumiMDApp.swift`: app entry point, `DocumentGroup`
  - `MarkdownDocument.swift`: the `.md` file document model
  - `MarkdownTextView.swift`: `NSTextView` wrapper used as the editor
  - `ContentView.swift`: the document window's content

## License
TBD
