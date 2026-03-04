# JuliaSyntaxBridge — Proof of Concept

IMAGES: 
<img width="1192" height="672" alt="2" src="https://github.com/user-attachments/assets/f8ea8583-8608-41ab-9f0f-13aa2a4de539" />
<img width="1167" height="635" alt="1" src="https://github.com/user-attachments/assets/2539ff89-ad49-4de9-bc23-f114cec3080d" />
<img width="1148" height="686" alt="3" src="https://github.com/user-attachments/assets/1f22419e-b2e2-4d76-bcb0-be147907c512" />

A proof-of-concept bridge connecting
`JuliaSyntaxHighlighting.jl` (Julia stdlib) to HTML `<span>` elements
using `hljs-*` CSS classes compatible with all existing Documenter.jl themes.

Built as part of a GSoC 2026 proposal for:
**"JuliaSyntax-based code highlighter for Documenter.jl"**

## The Problem

Documenter.jl currently highlights Julia code by either:
1. Shipping raw text to the browser and letting `highlight.js` regex-scan it client-side
2. Spawning one `Node.js` subprocess per code block at build time

Both approaches delegate Julia syntax understanding to a JavaScript
regex engine that has no knowledge of Julia's actual grammar.

## The Solution
```
Before:
Julia code → Node.js subprocess → highlight.js regex → colored HTML
              ↑ IPC overhead       ↑ regex, no semantics

After:
Julia code → JuliaSyntaxHighlighting.highlight() → bridge → colored HTML
              ↑ in-process stdlib    ↑ real AST, zero IPC
```

## What This POC Demonstrates

| Case | highlight.js | This Bridge |
|------|-------------|-------------|
| `@time`, `@assert` — macros | Often wrong | ✓ Correct |
| `"Hello $name"` — interpolation | Flat token, no separation | ✓ String segments correctly tokenized, interpolation delimiters separated |
| `α`, `∇f`, `Δt` — unicode | Often broken | ✓ Correct |
| `0x1f`, `1.5e-3` — numerics | Sometimes wrong | ✓ Correct |
| `#= nested =# ` — block comments | Wrong | ✓ Correct |
| Malformed code | May crash | ✓ Graceful recovery |
| Double-nested type spans | N/A | Minor redundancy — renders identically, cleaned up in final DOM.jl integration |

## Run It

Requirements: Julia 1.11+
```bash
git clone https://github.com/YashVardhan2496/JuliaSyntaxBridge-poc
cd JuliaSyntaxBridge-poc
julia JuliaSyntaxBridge_poc.jl
```

Then open `highlighted.html` in any browser.

## Key Properties

- **Zero new dependencies** — `JuliaSyntaxHighlighting.jl` ships with Julia stdlib
- **Zero subprocesses** — pure in-process Julia
- **Zero regex** — real AST parsing via `JuliaSyntax.GreenNode`
- **Zero CSS changes** — reuses existing `hljs-*` classes from all Documenter themes
- **Graceful degradation** — unknown faces → plain text, never crash

## Architecture
```
JuliaSyntaxHighlighting.highlight(code)    ← stdlib, zero deps
        ↓
AnnotatedString with julia_* face annotations
[(1:8, :face, :julia_keyword), ...]
        ↓
FACE_TO_CSS mapping table
:julia_keyword → "hljs-keyword"
:julia_string  → "hljs-string"
        ↓
<span class="hljs-keyword">function</span>
```

## Files
```
JuliaSyntaxBridge_poc.jl   ← entire POC (~320 lines)
highlighted.html            ← generated output (open in browser)
README.md                   ← this file
```

> **Note:** This POC emits raw HTML strings for simplicity. 
> The final Documenter.jl integration will use `DOM.jl` 
> constructors instead, consistent with HTMLWriter.jl patterns.



