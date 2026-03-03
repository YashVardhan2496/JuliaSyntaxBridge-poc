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
