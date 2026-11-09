# Project Plan: Sumi Md, a Lightweight Markdown Editor for macOS

**Name:** Sumi Md (from sumi, Japanese 墨, "ink"). Repository: `sumi-md`.

## Goal
A fast, native, document-based Markdown editor that opens instantly, stays small, and does a few things well.

## Design Principles
- **Native first:** SwiftUI + AppKit, no Electron, no embedded web editor framework.
- **Plain text always:** files are standard `.md`, nothing proprietary.
- **Few features, done well:** no notes library, no sync, no plugins.
- **Sandbox-ready from day one:** keeps both Mac App Store and direct distribution possible.

## Editing Model
Two views of the same document, one pane at a time:

1. **Styled raw editor (default).** Plain Markdown text with live syntax styling: larger headings, real bold/italic, dimmed syntax markers, monospaced code blocks. Built with `NSTextView` attributes, so it stays fast and keeps the text exactly as typed.
2. **Rendered view (toggle, Cmd+E).** Full-width rendered HTML in a `WKWebView` for reading and checking tables, task lists, and links. Read-only.

Not in v1: true WYSIWYG (Typora-style) editing, and split view. Split view can be added later as an optional mode.

## Tech Stack
| Area | Choice |
|---|---|
| App shell | SwiftUI, `DocumentGroup` (windows, tabs, autosave, versions, Open Recent) |
| Editor | `NSTextView` (TextKit 2) wrapped via `NSViewRepresentable` |
| Parsing / highlighting | `swift-markdown` (cmark-gfm) for parsing; map AST ranges to text attributes |
| Rendered view | `WKWebView` fed by HTML generated from the same parser, with bundled CSS (light/dark) |
| Minimum macOS | 26.6.2 (macOS only) |

## v1 Features
- Open, edit, save `.md` files with autosave
- Live styled-raw editing
- Cmd+E toggle to rendered view
- GitHub-flavored Markdown: tables, task lists, strikethrough, fenced code blocks
- Light and dark mode
- Font and size preferences
- Find and replace
- Word and character count

## Later (v1.1+)
- QuickLook extension (Spacebar preview in Finder)
- Syntax highlighting inside code blocks
- Mermaid diagrams and math
- Export to HTML and PDF
- Outline sidebar, focus mode
- Optional split view

## Out of Scope
Notes library, wiki-links/graph, sync, plugins, collaboration.

## Milestones
1. **Skeleton:** Xcode project, `DocumentGroup`, plain-text editing, open/save/autosave
2. **Styling:** Markdown parsing and live attribute styling in the editor
3. **Rendered view:** HTML generation, `WKWebView`, Cmd+E toggle, CSS themes
4. **Polish:** preferences, find/replace, word count, performance check on large files
5. **Release prep:** icon, sandbox entitlements, signing, notarization, distribution

## Key Risks
- **Editor performance on large files:** restyle only the edited paragraph range, not the whole document.
- **Styling vs. cursor/selection bugs:** apply attributes without touching the text storage's string.
- **Keeping editor and rendered view consistent:** one parser for both.

## Open Decisions
- Distribution: Mac App Store vs. direct download (design for sandbox either way)
- Domain (check `sumi-md.app`, `getsumi.md`, or similar at a registrar)
- Free vs. paid
