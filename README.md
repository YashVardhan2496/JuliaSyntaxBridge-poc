# JuliaSyntaxBridge — Proof of Concept

> Standalone proof-of-concept · Addresses Issue #2224 · JuliaDocs / Documenter.jl

IMAGES:
<img width="1324" height="725" alt="1" src="https://github.com/user-attachments/assets/bf98858b-d5d0-4d1c-9071-1e24122fa331" />
<img width="1290" height="652" alt="2" src="https://github.com/user-attachments/assets/2fcf1bae-db92-45cf-9ff7-0ef80dc1b8ce" />
<img width="1257" height="738" alt="3" src="https://github.com/user-attachments/assets/e75707db-252c-426d-b66f-04c073ca8906" />
<img width="1353" height="720" alt="4" src="https://github.com/user-attachments/assets/74d3f730-2efc-47db-accd-2a64a95f7a9b" />
<img width="1338" height="718" alt="5" src="https://github.com/user-attachments/assets/3dc53d42-2921-4e12-898b-fe9f7c1e1071" />
<img width="1216" height="684" alt="6" src="https://github.com/user-attachments/assets/2e8ca706-036d-4da1-b420-49737805a32e" />
<img width="1264" height="614" alt="7" src="https://github.com/user-attachments/assets/38a6821f-221d-4da7-9186-7bdab33f67c1" />


A proof-of-concept bridge connecting `JuliaSyntaxHighlighting.jl` (Julia stdlib) to
Documenter.jl's HTML and LaTeX/PDF output pipelines — zero new dependencies, real AST
parsing, both output paths working.

## Benchmark

Measured on **Apple M2 (8GB), Julia 1.12.5** — 50-run `time_ns()` average after 2 warmup runs.
Sample: 1101 characters across 13 representative code blocks.

| Path | Avg per run | vs Node.js cold-start |
|------|-------------|----------------------|
| HTML path | **0.387 ms** | Node.js subprocess spawn alone costs ~40–80ms before processing begins |
| LaTeX path | **1.236 ms** | No equivalent exists — PDF highlighting is impossible with client-side JS |

> Node.js apples-to-apples comparison deferred to Week 9 of GSoC —
> both paths on same machine simultaneously using BenchmarkTools.jl.

## The Problem

Documenter.jl currently highlights Julia code by either:
1. Shipping raw text to the browser and letting `highlight.js` regex-scan it client-side
2. Spawning one `Node.js` subprocess per code block at build time

Both approaches delegate Julia syntax understanding to a JavaScript regex engine
that has no knowledge of Julia's actual grammar. Neither path produces correct
output for PDF/LaTeX. `JuliaSyntaxHighlighting.jl` has been in Julia's stdlib
since 1.12 and is completely unused by Documenter.

## The Solution

```
Before:
Julia code → Node.js subprocess → highlight.js regex → colored HTML (HTML only)
              ↑ IPC overhead       ↑ regex, no semantics  ↑ PDF gets nothing

After:
Julia code → JuliaSyntaxHighlighting.highlight() → bridge → colored HTML
              ↑ in-process stdlib    ↑ real AST, zero IPC
                                                  → colored LaTeX/PDF  ← NEW
```

## What This PoC Demonstrates

| Case | highlight.js | This Bridge |
|------|-------------|-------------|
| `@time`, `@assert` — macros | Often wrong | ✓ Correct |
| `"Hello $name"` — interpolation | Flat token, no nesting | ✓ Correctly nested string + interpolation spans |
| `α`, `∇f`, `Δt` — unicode | Often broken | ✓ Correct (byte-safe sort, FIX 1) |
| `0x1f`, `0b1010_1100`, `1.5e-3` — numerics | Sometimes wrong | ✓ All Julia literal forms correct |
| `` `echo $msg` `` — command strings | Not recognised | ✓ `:julia_cmd` + `:julia_cmd_delim` both mapped |
| `#= nested #= inner =# =#` — block comments | Wrong | ✓ Any nesting depth, AST native |
| Malformed / incomplete code | May crash | ✓ Graceful recovery — zero-width guard (FIX 2) |
| LaTeX/PDF output | Impossible | ✓ `\DocumenterJLKeyword{function}` macros emitted |
| XSS injection in code | Unsafe | ✓ All output via `write()` + `escape_html()` (FIX 3) |

## Test Results

```
13/13 functional tests passed (Julia 1.12.5)
 6/6  XSS safety assertions passed
 6/6  LaTeX injection safety assertions passed
13/13 character completeness checks passed
```

## Run It

**Requirements: Julia 1.12+**
(`JuliaSyntaxHighlighting.jl` shipped as stdlib in Julia 1.12 — not available in 1.11)

```bash
git clone https://github.com/YashVardhan2496/JuliaSyntaxBridge-poc
cd JuliaSyntaxBridge-poc
julia JuliaSyntaxBridge_poc.jl
```

Then open `highlighted.html` in any browser.

## Architecture

```
JuliaSyntaxHighlighting.highlight(code)    ← stdlib, zero deps, real AST
        ↓
get_face_annotations()                     ← isolates experimental Base.annotations() API
        ↓                                    one wrapper — one edit point if API changes
Vector of (region::UnitRange, face::Symbol)
[(1:8, :julia_keyword), (10:22, :julia_string), ...]
        ↓
annotation_sort_key()                      ← Unicode-safe byte sort (FIX 1)
        ↓
        ├── HTML path                       ← emit_range_html() recursive nesting
        │   FACE_TO_CSS mapping
        │   :julia_keyword → "hljs-keyword"
        │   :julia_string  → "hljs-string"
        │   → <span class="hljs-keyword">function</span>
        │
        └── LaTeX/PDF path                 ← emit_range_latex() same algorithm
            FACE_TO_LATEX mapping
            :julia_keyword → "DocumenterJLKeyword"
            :julia_string  → "DocumenterJLString"
            → \DocumenterJLKeyword{function}
```

## Key Properties

- **Zero new dependencies** — `JuliaSyntaxHighlighting.jl` ships with Julia 1.12+ stdlib
- **Zero subprocesses** — pure in-process Julia, no Node.js required
- **Zero regex** — real AST parsing via `JuliaSyntax.GreenNode`
- **Zero CSS changes** — reuses existing `hljs-*` classes from all 6 Documenter themes
- **Both output paths** — HTML spans and LaTeX `\DocumenterJL*{}` macros
- **Graceful degradation** — Julia < 1.12 falls back silently, unknown faces → plain text, never crash
- **XSS safe** — all output via `write()` calls, never string interpolation

## Eight Fixes Over Naive Implementation

| Fix | Problem | Solution |
|-----|---------|----------|
| FIX 1 | Annotation sort used string length — miscounts multibyte chars (α = 2 bytes, 1 char) | Sort by `last(region)-first(region)` — byte span, not char count |
| FIX 2 | Zero-width annotations on incomplete code caused infinite recursion | `from > to && return` guard at top of recursive function |
| FIX 3 | HTML assembled by string joins — XSS risk if code contains `<` or `&` | All output via `write()` + `escape_html()` — no interpolation |
| FIX 4 | REPL blocks contain prompts, output, errors — not just code | Per-line routing: `julia>` / continuation / `ERROR:` / output |
| FIX 5 | VERSION guard was set to `v"1.11"` — package was removed before that release | Guard set to `v"1.12"` — the actual stdlib release |
| FIX 6 | `Base.annotations()` is marked experimental — change risk | All access behind `get_face_annotations()` wrapper — one edit point |
| FIX 7 | Annotations crossing region boundaries were silently dropped — characters lost | Straddling spans emitted as plain escaped text — no characters dropped |
| FIX 8 | Mixed indexed/named annotation field access throughout v2 | Consistent named field access (`.region`, `.label`, `.value`) throughout |

## Face Coverage

All 46 faces in `JuliaSyntaxHighlighting.HIGHLIGHT_FACES` are mapped — verified against
the live stdlib source. Notable findings from the audit:

- `:julia_cmd` and `:julia_cmd_delim` were missing from earlier versions — added after audit
- `:julia_subst` was invented and does not exist in stdlib — removed
- 18 rainbow paren/bracket/curly entries (6 levels × 3 types) all mapped

## Files

```
JuliaSyntaxBridge_poc.jl   ← entire PoC — 892 lines raw, ~320 non-blank/non-comment
highlighted.html            ← generated output (open in browser)
README.md                   ← this file
```

> **Note:** This PoC emits raw HTML strings via `IOBuffer` + `write()` for simplicity,
> since it runs standalone without importing Documenter.
> The final `src/html/JuliaSyntaxBridge.jl` integration will use Documenter's DOM DSL
> (`DOM.Tag(:span)[".hljs-*"](inner...)`) instead — the algorithm is identical,
> only the output construction method changes.
