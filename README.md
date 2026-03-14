# JuliaSyntaxBridge — Proof of Concept

Images of generated html output:



> Standalone proof-of-concept · Addresses Issue #2224 · JuliaDocs / Documenter.jl

## Output

![Basic function and command strings](https://github.com/user-attachments/assets/bf98858b-d5d0-4d1c-9071-1e24122fa331)
![Macros and string interpolation](https://github.com/user-attachments/assets/2fcf1bae-db92-45cf-9ff7-0ef80dc1b8ce)
![Unicode and numbers](https://github.com/user-attachments/assets/e75707db-252c-426d-b66f-04c073ca8906)
![Types and REPL](https://github.com/user-attachments/assets/74d3f730-2efc-47db-accd-2a64a95f7a9b)

## Benchmark

**Apple M2 (8GB) · Julia 1.12.5 · 50-run `time_ns()` average · 2 warmup runs**
Sample: 1157 chars · 14 blocks

| Path | Avg per run |
|------|-------------|
| HTML path | **1.251 ms** |
| LaTeX path | **0.404 ms** |

Node.js subprocess spawn alone costs ~40–80ms before any processing begins.
Full apples-to-apples BenchmarkTools.jl comparison deferred to GSoC integration phase.

## The Problem

Documenter.jl highlights Julia code by either:
1. Shipping raw text to the browser and letting `highlight.js` regex-scan it client-side
2. Spawning one `Node.js` subprocess per code block at build time

Both delegate Julia syntax understanding to a JavaScript regex engine with no knowledge of Julia's actual grammar. Neither produces correct output for PDF. `JuliaSyntaxHighlighting.jl` has been in Julia's stdlib since 1.12 and is completely unused by Documenter.

## The Solution

```
Before:
Julia code → Node.js subprocess → highlight.js regex → HTML only, no PDF

After:
Julia code → JuliaSyntaxHighlighting.highlight() → bridge → HTML spans
              ↑ in-process stdlib · real AST · No IPC overhead         → LaTeX macros · PDF works
```

## What This PoC Demonstrates

| Case | highlight.js | This Bridge |
|------|-------------|-------------|
| `@time`, `@assert` — macros | Often wrong | ✓ Correct |
| `"Hello $name"` — interpolation | Flat token | ✓ Correctly nested |
| `α`, `∇f`, `Δt` — unicode | Often broken | ✓ Correct (byte-safe sort) |
| `0x1f`, `0b1010_1100`, `1.5e-3` — numerics | Sometimes wrong | ✓ All literal forms correct |
| `` `echo $msg` `` — command strings | Not recognised | ✓ `:julia_cmdstring` mapped |
| `#= nested #= inner =# =#` — block comments | Wrong | ✓ Any nesting depth |
| Incomplete / malformed code | May crash | ✓ Graceful — zero-width guard |
| LaTeX/PDF output | Impossible | ✓ `\DocumenterJLKeyword{function}` macros |
| XSS injection in code | Unsafe | ✓ All output via `write()` + `escape_html()` |

## Test Results

```
14/14 functional tests passed (Julia 1.12.5)
 4/4  XSS safety assertions passed
 2/2  LaTeX safety assertions passed
13/13 character completeness checks passed
```

## Run It

**Requirements: Julia 1.12+**

```bash
git clone https://github.com/YashVardhan2496/JuliaSyntaxBridge-poc
cd JuliaSyntaxBridge-poc
julia JuliaSyntaxBridge_poc.jl
```

Open `highlighted.html` in any browser.

## Architecture

```
using JuliaSyntaxHighlighting
JuliaSyntaxHighlighting.highlight(code)    ← stdlib · zero deps · real AST
        ↓
get_face_annotations()                     ← isolates experimental Base.annotations() API
        ↓
Vector of (region::UnitRange{Int64}, face::Symbol)   ← 43 faces 
        ↓
annotation_sort_key()                      ← byte sort · Unicode-safe
        ↓
        ├── HTML path  → emit_range_html() recursive
        │   :julia_keyword → "hljs-keyword"
        │   → <span class="hljs-keyword">function</span>
        │
        └── LaTeX path → emit_range_latex() same algorithm
            :julia_keyword → "DocumenterJLKeyword"
            → \DocumenterJLKeyword{function}
```

## Key Properties

- **Zero new dependencies** — `JuliaSyntaxHighlighting.jl` ships with Julia 1.12+
- **Zero subprocesses** — pure in-process Julia, no Node.js
- **Zero regex** — real AST via `JuliaSyntax.GreenNode`
- **Zero CSS changes** — reuses existing `hljs-*` classes from all 6 Documenter themes
- **Both output paths** — HTML spans and LaTeX `\DocumenterJL*{}` macros
- **Graceful degradation** — Julia < 1.12 falls back to plain text silently
- **XSS safe** — all output via `write()`, never string interpolation

## Face Coverage

All 43 faces in `JuliaSyntaxHighlighting.HIGHLIGHT_FACES` mapped — verified against live runtime on Julia 1.12.5 via:

```julia
for (name, _) in JuliaSyntaxHighlighting.HIGHLIGHT_FACES
    println(name)
end
```

- 18 rainbow paren/bracket/curly entries (6 levels × 3 types) all mapped
- `:julia_cmdstring` is the correct face name for backtick command strings
- `:julia_backslash_literal` maps to `hljs-string` — `hljs-char` is absent from `default.css`

## Files

```
JuliaSyntaxBridge_poc.jl   ← entire PoC
highlighted.html            ← generated output
README.md                   ← this file
```

> This PoC emits raw HTML via `IOBuffer` + `write()` since it runs standalone without
> importing Documenter. The final integration uses `DOM.Tag(:span)[".hljs-*"](inner...)`
> — algorithm identical, output construction changes.

## Changelog

**v4**
- Guard: `VERSION >= v"1.12"` → `isfile(joinpath(Sys.STDLIB, "JuliaSyntaxHighlighting", "src", "JuliaSyntaxHighlighting.jl"))` — verified correct on Julia 1.12.5 in fresh REPL
- Import: `import Base.JuliaSyntaxHighlighting` → `using JuliaSyntaxHighlighting`
- Face table: verified against live runtime and official julia documentation — 43 faces
- Fixed: `:julia_backslash_literal` → `hljs-string` (`hljs-char` absent from `default.css`)
- Added: character completeness test and face coverage test case (14 tests total)

**v3**
- LaTeX path added
- Straddling annotation fallback
- `Base.annotations()` isolated behind wrapper
- Consistent named field access throughout
