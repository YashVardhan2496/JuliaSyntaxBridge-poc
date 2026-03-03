# JuliaSyntaxBridge — Proof of Concept

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
| `"Hello $name"` — interpolation | Regex cannot model | ✓ Correct |
| `α`, `∇f`, `Δt` — unicode | Often broken | ✓ Correct |
| `0x1f`, `1.5e-3` — numerics | Sometimes wrong | ✓ Correct |
| `#= nested =# ` — block comments | Wrong | ✓ Correct |
| Malformed code | May crash | ✓ Graceful recovery |

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
JuliaSyntaxBridge_poc.jl   ← entire POC (~180 lines)
highlighted.html            ← generated output (open in browser)
README.md                   ← this file
```
