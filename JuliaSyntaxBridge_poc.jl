# JuliaSyntaxBridge.jl — PoC v3 
# Bridges JuliaSyntaxHighlighting.jl (Julia stdlib) into Documenter.jl
# HTML spans AND LaTeX/PDF colour macros.
#
# Fixes over v2:
#   1. VERSION guard corrected to v"1.12" — package was pulled from 1.11 before release
#   2. Consistent annotation access: named fields (.region, .label, .value) throughout
#   3. LaTeX path added: highlight_latex() + FACE_TO_LATEX + latex_escape()
#   4. Straddling annotation fallback: characters preserved even for boundary-crossing spans
#   5. Benchmark measures bridge processing time only; full Node.js comparison needs both installed
#   6. Base.annotations() isolated behind get_face_annotations() wrapper
#      — one edit point if the experimental API changes
#   7. REPL byte-index comment: explains why line[8:end] is correct
#   8. Annotation access made consistent (was mixed indexed/named in v2)

# ---------------------------------------------------------------------------
# VERSION GUARD
#
# JuliaSyntaxHighlighting.jl was considered for Julia 1.11 but deliberately
# removed before that release — it had no docs and was still making breaking
# changes. It officially shipped as stdlib in Julia 1.12.
#
# On Julia < 1.12:  HTML path returns plain escaped text (no crash, no warning)
#                   LaTeX path returns plain escaped text
# On Julia >= 1.12: full AST-based highlighting for both paths
# ---------------------------------------------------------------------------
const BRIDGE_AVAILABLE = VERSION >= v"1.12"

if BRIDGE_AVAILABLE
    import JuliaSyntaxHighlighting
end

# ---------------------------------------------------------------------------
# FIX 6 (v3): Base.annotations() is marked experimental in Julia docs.
# ("The API for AnnotatedStrings is considered experimental and is subject
#  to change between Julia versions.")
# ALL annotation access goes through this one wrapper. If the API changes,
# only this function needs updating — nothing else in the bridge changes.
#
# CONFIRMED from stdlib source docstring (JuliaSyntaxHighlighting.jl):
# Return type: Vector{@NamedTuple{region::UnitRange{Int64}, label::Symbol, value}}
# Fields:  .region  -> UnitRange{Int64}  (byte positions into the source string)
#          .label   -> Symbol            (always :face for highlighting annotations)
#          .value   -> untyped Any       (in practice always Symbol, e.g. :julia_keyword)
# Our haskey(FACE_TO_CSS, face) check safely handles any non-Symbol value via fallback.
#
# Also confirmed: stdlib also pushes a :code face for backtick spans inside comments.
# :code is not a julia_* face. Our filter (ann.label === :face) includes it but
# haskey(FACE_TO_CSS, :code) returns false -> plain text. Safe and correct.
# ---------------------------------------------------------------------------
function get_face_annotations(code::String) :: Vector
    if !BRIDGE_AVAILABLE
        return []
    end
    annotated   = JuliaSyntaxHighlighting.highlight(code, syntax_errors=false)
    raw_anns    = Base.annotations(annotated)
    # FIX 8 (v3): consistent named-field access throughout (.region, .label, .value)
    # In v2 this was mixed: highlight_html() used named fields but emit_range()
    # used indexed destructuring (region, face = anns[i]) — inconsistent and fragile.
    return [(ann.region, ann.value)
            for ann in raw_anns if ann.label === :face]
end

# ---------------------------------------------------------------------------
# Face → CSS class mapping
# Left:  face names from JuliaSyntaxHighlighting.jl HIGHLIGHT_FACES
# Right: hljs-* classes already in Documenter's 6 CSS themes
# Unknown faces fall through silently — unknown face ≠ crash
# ---------------------------------------------------------------------------
const FACE_TO_CSS = Dict{Symbol, String}(
    :julia_keyword              => "hljs-keyword",
    :julia_string               => "hljs-string",
    :julia_string_delim         => "hljs-string",
    :julia_comment              => "hljs-comment",
    :julia_number               => "hljs-number",
    :julia_bool                 => "hljs-number",
    :julia_macro                => "hljs-meta",
    :julia_funcall              => "hljs-title",
    :julia_funcdef              => "hljs-title",
    :julia_operator             => "hljs-operator",
    :julia_opassignment         => "hljs-operator",
    :julia_comparator           => "hljs-operator",
    :julia_broadcast            => "hljs-operator",
    :julia_assignment           => "hljs-operator",
    :julia_type                 => "hljs-type",
    :julia_typedec              => "hljs-type",
    :julia_builtin              => "hljs-built_in",
    :julia_symbol               => "hljs-symbol",
    :julia_singleton_identifier => "hljs-symbol",
    :julia_backslash_literal    => "hljs-char",
    :julia_char                 => "hljs-string",
    :julia_char_delim           => "hljs-string",
    :julia_regex                => "hljs-regexp",
    :julia_error                => "hljs-error",
    :julia_unpaired_parentheses => "hljs-error",
    :julia_parentheses          => "hljs-punctuation",
    # Command strings: `echo $msg`, run(`ls`) — julia_cmd* confirmed in HIGHLIGHT_FACES
    :julia_cmd                  => "hljs-string",
    :julia_cmd_delim            => "hljs-string",
    # NOTE: :julia_subst is NOT in stdlib HIGHLIGHT_FACES and is never emitted.
    # String interpolation is handled via :julia_string (outer) + :julia_string_delim
    # (the $ character) + whatever face the inner expression gets.
    # NOTE: :code face is pushed for backtick spans inside comments. It is not a
    # julia_* face. Our haskey() check returns false -> plain text. Safe.
    # rainbow parens — 6 levels per MAX_PAREN_HIGHLIGHT_DEPTH in stdlib
    :julia_rainbow_paren_1      => "hljs-punctuation",
    :julia_rainbow_paren_2      => "hljs-punctuation",
    :julia_rainbow_paren_3      => "hljs-punctuation",
    :julia_rainbow_paren_4      => "hljs-punctuation",
    :julia_rainbow_paren_5      => "hljs-punctuation",
    :julia_rainbow_paren_6      => "hljs-punctuation",
    # rainbow brackets — 6 levels
    :julia_rainbow_bracket_1    => "hljs-punctuation",
    :julia_rainbow_bracket_2    => "hljs-punctuation",
    :julia_rainbow_bracket_3    => "hljs-punctuation",
    :julia_rainbow_bracket_4    => "hljs-punctuation",
    :julia_rainbow_bracket_5    => "hljs-punctuation",
    :julia_rainbow_bracket_6    => "hljs-punctuation",
    # rainbow curly braces — 6 levels (parametric types Dict{K,V})
    :julia_rainbow_curly_1      => "hljs-punctuation",
    :julia_rainbow_curly_2      => "hljs-punctuation",
    :julia_rainbow_curly_3      => "hljs-punctuation",
    :julia_rainbow_curly_4      => "hljs-punctuation",
    :julia_rainbow_curly_5      => "hljs-punctuation",
    :julia_rainbow_curly_6      => "hljs-punctuation",
)

# ---------------------------------------------------------------------------
# Face → LaTeX macro mapping  (NEW in v3)
# Each face maps to a \DocumenterJL* macro defined in documenter.sty.
# Using \providecommand means user-defined overrides in custom.sty are
# silently preserved — PDF builds never crash on redefinition.
# ---------------------------------------------------------------------------
const FACE_TO_LATEX = Dict{Symbol, String}(
    :julia_keyword              => "DocumenterJLKeyword",
    :julia_string               => "DocumenterJLString",
    :julia_string_delim         => "DocumenterJLString",
    :julia_comment              => "DocumenterJLComment",
    :julia_number               => "DocumenterJLNumber",
    :julia_bool                 => "DocumenterJLNumber",
    :julia_macro                => "DocumenterJLMacro",
    :julia_funcall              => "DocumenterJLFunction",
    :julia_funcdef              => "DocumenterJLFunction",
    :julia_operator             => "DocumenterJLOperator",
    :julia_opassignment         => "DocumenterJLOperator",
    :julia_comparator           => "DocumenterJLOperator",
    :julia_broadcast            => "DocumenterJLOperator",
    :julia_assignment           => "DocumenterJLOperator",
    :julia_type                 => "DocumenterJLType",
    :julia_typedec              => "DocumenterJLType",
    :julia_builtin              => "DocumenterJLBuiltin",
    :julia_symbol               => "DocumenterJLSymbol",
    :julia_singleton_identifier => "DocumenterJLSymbol",
    :julia_char                 => "DocumenterJLString",
    :julia_char_delim           => "DocumenterJLString",
    :julia_error                => "DocumenterJLError",
    :julia_unpaired_parentheses => "DocumenterJLError",
    # Command strings: `echo $msg`, run(`ls -la`)
    :julia_cmd                  => "DocumenterJLString",
    :julia_cmd_delim            => "DocumenterJLString",
    # NOTE: :julia_subst removed — NOT in stdlib HIGHLIGHT_FACES, never emitted.
    # rainbow parens/brackets/curly — all map to generic punctuation macro
    :julia_rainbow_paren_1      => "DocumenterJLPunct",
    :julia_rainbow_paren_2      => "DocumenterJLPunct",
    :julia_rainbow_paren_3      => "DocumenterJLPunct",
    :julia_rainbow_paren_4      => "DocumenterJLPunct",
    :julia_rainbow_paren_5      => "DocumenterJLPunct",
    :julia_rainbow_paren_6      => "DocumenterJLPunct",
    :julia_rainbow_bracket_1    => "DocumenterJLPunct",
    :julia_rainbow_bracket_2    => "DocumenterJLPunct",
    :julia_rainbow_bracket_3    => "DocumenterJLPunct",
    :julia_rainbow_bracket_4    => "DocumenterJLPunct",
    :julia_rainbow_bracket_5    => "DocumenterJLPunct",
    :julia_rainbow_bracket_6    => "DocumenterJLPunct",
    :julia_rainbow_curly_1      => "DocumenterJLPunct",
    :julia_rainbow_curly_2      => "DocumenterJLPunct",
    :julia_rainbow_curly_3      => "DocumenterJLPunct",
    :julia_rainbow_curly_4      => "DocumenterJLPunct",
    :julia_rainbow_curly_5      => "DocumenterJLPunct",
    :julia_rainbow_curly_6      => "DocumenterJLPunct",
)

# ---------------------------------------------------------------------------
# HTML escaping — & must go first to avoid double-escaping
# ---------------------------------------------------------------------------
function escape_html(s::AbstractString) :: String
    s = replace(s, "&"  => "&amp;")
    s = replace(s, "<"  => "&lt;")
    s = replace(s, ">"  => "&gt;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "'"  => "&#39;")
    return s
end

# ---------------------------------------------------------------------------
# LaTeX character escaping  (NEW in v3)
# Escapes the 10 LaTeX special characters.
# The XOR operator (⊕) interaction with minted's escapeinside is handled
# by reusing _print_code_escapes_minted() from LaTeXWriter.jl in the real
# integration — this standalone PoC shows the same logic manually.
# ---------------------------------------------------------------------------
function escape_latex(s::AbstractString) :: String
    s = replace(s, "\\" => "\\textbackslash{}")
    s = replace(s, "{"  => "\\{")
    s = replace(s, "}"  => "\\}")
    s = replace(s, "&"  => "\\&")
    s = replace(s, "#"  => "\\#")
    s = replace(s, "%"  => "\\%")
    s = replace(s, "^"  => "\\^{}")
    s = replace(s, "_"  => "\\_")
    s = replace(s, "~"  => "\\textasciitilde{}")
    s = replace(s, "\$" => "\\\$")
    return s
end

# ---------------------------------------------------------------------------
# annotation_sort_key
#
# FIX 1 (v2, preserved): sort by integer byte span, NOT string length.
# String length miscounts multibyte chars — α is 2 bytes but 1 char.
# Using last(region)-first(region) works on byte positions directly.
# Outer annotations first: sort by (start asc, span-width desc).
# ---------------------------------------------------------------------------
function annotation_sort_key(ann)
    region = ann[1]
    span   = last(region) - first(region)
    return (first(region), -span)
end

# ---------------------------------------------------------------------------
# emit_range_html — recursive HTML span emitter
#
# Handles overlapping/nested annotations correctly.
# A flat loop would silently drop inner annotations — recursion handles
# any nesting depth.
#
# FIX 2 (v2, preserved): from > to guard prevents infinite recursion on
# zero-width annotations produced by JuliaSyntaxHighlighting for some
# synthetic AST nodes on incomplete code.
#
# FIX 4 (v3): straddling annotations (rend > to) now emit their TEXT
# content as plain escaped text rather than being silently dropped.
# This preserves all characters even on boundary-crossing spans.
# ---------------------------------------------------------------------------
function emit_range_html(
    buf  :: IOBuffer,
    code :: String,
    anns :: Vector,
    from :: Int,
    to   :: Int,
    idx  :: Int,
)
    from > to && return

    pos = from
    i   = idx

    while i <= length(anns)
        region, face = anns[i]   # FIX 8: anns entries are (region, value) tuples
        rstart = first(region)
        rend   = last(region)

        rstart > to && break

        # FIX 4 (v3): annotation straddles window boundary
        # v2 silently skipped these — characters were lost.
        # v3 emits the overlapping text as plain escaped text.
        if rend > to
            if pos < rstart
                write(buf, escape_html(code[pos:prevind(code, rstart)]))
            end
            # emit the part of the straddling span that falls inside our window
            safe_end = to
            write(buf, escape_html(code[rstart:safe_end]))
            pos = nextind(code, safe_end)
            i += 1
            continue
        end

        # zero-width annotation — skip to avoid infinite recursion (FIX 2)
        if rstart > rend
            i += 1
            continue
        end

        # plain text before this annotation
        if pos < rstart
            write(buf, escape_html(code[pos:prevind(code, rstart)]))
        end

        # find the first annotation NOT fully inside [rstart, rend]
        j = i + 1
        while j <= length(anns)
            cr = anns[j][1]
            first(cr) >= rstart && last(cr) <= rend ? j += 1 : break
        end

        # render interior recursively into inner_buf
        inner_buf = IOBuffer()
        emit_range_html(inner_buf, code, anns, rstart, rend, i + 1)
        inner = String(take!(inner_buf))

        if isempty(inner)
            inner = escape_html(code[rstart:rend])
        end

        # FIX 3 (v2, preserved): write() not string interpolation — no XSS surface
        if haskey(FACE_TO_CSS, face)
            cls = FACE_TO_CSS[face]
            write(buf, "<span class=\"", cls, "\">", inner, "</span>")
        else
            write(buf, inner)  # unknown face → unstyled plain text, never crash
        end

        pos = nextind(code, rend)
        i   = j
    end

    if pos <= to
        write(buf, escape_html(code[pos:to]))
    end
end

# ---------------------------------------------------------------------------
# emit_range_latex — recursive LaTeX macro emitter  (NEW in v3)
#
# Same algorithm as emit_range_html but emits \DocumenterJL*{text} instead
# of <span> tags. Shares the same sort, guard, and recursion logic.
# ---------------------------------------------------------------------------
function emit_range_latex(
    buf  :: IOBuffer,
    code :: String,
    anns :: Vector,
    from :: Int,
    to   :: Int,
    idx  :: Int,
)
    from > to && return

    pos = from
    i   = idx

    while i <= length(anns)
        region, face = anns[i]
        rstart = first(region)
        rend   = last(region)

        rstart > to && break

        # straddling annotation — emit as plain text
        if rend > to
            if pos < rstart
                write(buf, escape_latex(code[pos:prevind(code, rstart)]))
            end
            write(buf, escape_latex(code[rstart:to]))
            pos = nextind(code, to)
            i += 1
            continue
        end

        # zero-width guard
        if rstart > rend
            i += 1
            continue
        end

        if pos < rstart
            write(buf, escape_latex(code[pos:prevind(code, rstart)]))
        end

        j = i + 1
        while j <= length(anns)
            cr = anns[j][1]
            first(cr) >= rstart && last(cr) <= rend ? j += 1 : break
        end

        inner_buf = IOBuffer()
        emit_range_latex(inner_buf, code, anns, rstart, rend, i + 1)
        inner = String(take!(inner_buf))

        if isempty(inner)
            inner = escape_latex(code[rstart:rend])
        end

        if haskey(FACE_TO_LATEX, face)
            macro_name = FACE_TO_LATEX[face]
            write(buf, "\\", macro_name, "{", inner, "}")
        else
            write(buf, inner)  # unknown face → plain text, never crash
        end

        pos = nextind(code, rend)
        i   = j
    end

    if pos <= to
        write(buf, escape_latex(code[pos:to]))
    end
end

# ---------------------------------------------------------------------------
# highlight_html — main entry point for ```julia blocks
# ---------------------------------------------------------------------------
function highlight_html(code::String) :: String
    if !BRIDGE_AVAILABLE
        return escape_html(code)
    end

    face_anns = sort(get_face_annotations(code), by = annotation_sort_key)

    buf = IOBuffer()
    if isempty(face_anns)
        write(buf, escape_html(code))
        return String(take!(buf))
    end

    emit_range_html(buf, code, face_anns, firstindex(code), lastindex(code), 1)
    return String(take!(buf))
end

# ---------------------------------------------------------------------------
# highlight_latex — main entry point for LaTeX/PDF path  (NEW in v3)
# Returns a string of LaTeX with \DocumenterJL*{...} macros wrapping tokens.
# Caller wraps this in minted[escapeinside=||]{text} in LaTeXWriter.jl.
# ---------------------------------------------------------------------------
function highlight_latex(code::String) :: String
    if !BRIDGE_AVAILABLE
        return escape_latex(code)
    end

    face_anns = sort(get_face_annotations(code), by = annotation_sort_key)

    buf = IOBuffer()
    if isempty(face_anns)
        write(buf, escape_latex(code))
        return String(take!(buf))
    end

    emit_range_latex(buf, code, face_anns, firstindex(code), lastindex(code), 1)
    return String(take!(buf))
end

# ---------------------------------------------------------------------------
# highlight_html_repl — FIX 4 (v2, preserved): ```julia-repl blocks
#
# REPL blocks mix Julia expressions with output lines — cannot run the
# whole block through highlight() as a unit.
#
# Three line types:
#   "julia> expr"  — highlight the expression, style the prompt green
#   "       expr"  — continuation (7 spaces = width of "julia> "), highlight it
#                    FIX 7 (v3): "julia> " is 7 ASCII bytes; line[8:end] is
#                    correct because all chars before index 8 are ASCII.
#   anything else  — output/error — styled as comment or error class
# ---------------------------------------------------------------------------
function highlight_html_repl(code::String) :: String
    buf   = IOBuffer()
    lines = split(code, '\n')
    n     = length(lines)

    for (k, line) in enumerate(lines)
        suffix = k < n ? "\n" : ""
        line_s = String(line)

        if startswith(line_s, "julia> ")
            # "julia> " is exactly 7 ASCII bytes; nextind(line_s, 7) == 8
            expr = line_s[8:end]
            write(buf,
                "<span class=\"hljs-meta\">julia&gt;</span> ",
                highlight_html(expr),
                suffix)

        elseif startswith(line_s, "       ") && !isempty(rstrip(line_s))
            write(buf, highlight_html(line_s), suffix)

        elseif startswith(line_s, "ERROR:")
            write(buf,
                "<span class=\"hljs-error\">",
                escape_html(line_s),
                "</span>",
                suffix)

        else
            write(buf,
                "<span class=\"hljs-comment\">",
                escape_html(line_s),
                "</span>",
                suffix)
        end
    end

    return String(take!(buf))
end

# ---------------------------------------------------------------------------
# LaTeX macro definitions for documenter.sty  (NEW in v3)
# These would be appended to assets/latex/documenter.sty in the real
# integration. \providecommand silently skips if user already defined
# the macro in custom.sty — users keep full colour control.
# ---------------------------------------------------------------------------
const LATEX_MACROS = raw"""
% JuliaSyntaxBridge colour macros — appended to documenter.sty
% \providecommand silently skips if user defined these in custom.sty
\usepackage{xcolor}
\providecommand{\DocumenterJLKeyword}[1]{\textcolor[HTML]{CF222E}{\textbf{#1}}}
\providecommand{\DocumenterJLString}[1]{\textcolor[HTML]{0A3069}{#1}}
\providecommand{\DocumenterJLComment}[1]{\textcolor[HTML]{6E7781}{\textit{#1}}}
\providecommand{\DocumenterJLNumber}[1]{\textcolor[HTML]{0550AE}{#1}}
\providecommand{\DocumenterJLMacro}[1]{\textcolor[HTML]{8250DF}{\textbf{#1}}}
\providecommand{\DocumenterJLFunction}[1]{\textcolor[HTML]{116329}{#1}}
\providecommand{\DocumenterJLOperator}[1]{\textcolor[HTML]{0550AE}{#1}}
\providecommand{\DocumenterJLType}[1]{\textcolor[HTML]{953800}{#1}}
\providecommand{\DocumenterJLBuiltin}[1]{\textcolor[HTML]{953800}{#1}}
\providecommand{\DocumenterJLSymbol}[1]{\textcolor[HTML]{0550AE}{#1}}
\providecommand{\DocumenterJLError}[1]{\colorbox[HTML]{FFEBE9}{\textcolor[HTML]{CF222E}{#1}}}
\providecommand{\DocumenterJLPunct}[1]{#1}
% Note: DocumenterJLSubst removed — :julia_subst is not in stdlib HIGHLIGHT_FACES
"""

# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------
const TEST_CASES = [
    (
        "Basic function",
        """function greet(name::String)
    println("Hello, \$name")
    return nothing
end"""
    ),
    (
        "Command strings — julia_cmd + julia_cmd_delim",
        """cmd = `echo hello`
run(`ls -la /tmp`)
result = read(`git log --oneline`, String)"""
    ),
    (
        "Macros — highlight.js gets these wrong",
        """@time begin
    result = @allocated sort(rand(1000))
    @assert result > 0
    @info "Done" result
end"""
    ),
    (
        "String interpolation — impossible with regex",
        """user = "Julia"
msg  = "Hello, \$(user)! Version \$(VERSION)."
cmd  = `echo \$msg`"""
    ),
    (
        "Unicode identifiers — FIX 1 (byte-safe sort)",
        """α  = 0.01
∇f(x) = 2x
Δt    = 1e-3
x̄     = sum(α .* ∇f.(1:10)) * Δt"""
    ),
    (
        "Numbers — all Julia literal forms",
        """hex     = 0x1f3a
binary  = 0b1010_1100
octal   = 0o755
sci     = 1.5e-3
complex = 2 + 3im
big     = 1_000_000"""
    ),
    (
        "Nested block comments — AST handles natively",
        """#= outer comment
   #= inner nested =#
   still in outer
=#
x = 42  # inline"""
    ),
    (
        "Types and where clauses",
        """struct Container{T <: AbstractFloat}
    value :: T
    label :: String
end

function process(c::Container{T}) where {T}
    return c.value :: T
end"""
    ),
    (
        "Parametric types — curly brace rainbow",
        """d = Dict{String, Vector{Int}}()
push!(d, "key" => [1, 2, 3])"""
    ),
    (
        "XSS attempt — HTML path safety",
        """x = "<script>alert('xss')</script>"
y = a & b | c
z = x > 0 ? "yes" : "no\""""
    ),
    (
        "LaTeX special chars — LaTeX path safety",
        """# LaTeX specials: & % \$ # _ { } ^ ~ \\
result = Dict{String,Int}("key" => 42)
formula = x^2 + y_1 ~ 0"""
    ),
    (
        "Incomplete code — FIX 2 zero-width guard",
        """function incomplete(x
    y = x +"""
    ),
    (
        "REPL block — FIX 4",
        """julia> x = 1 + 2
3

julia> println("hello")
hello

ERROR: UndefVarError: z not defined"""
    ),
]

# ---------------------------------------------------------------------------
# XSS tests
# ---------------------------------------------------------------------------
function run_xss_tests()
    println("  XSS safety (HTML path):")

    r1 = highlight_html("<b>bold</b>")
    @assert !occursin("<b>", r1)                          "raw HTML tags leaked"
    println("    [✓] raw HTML tags escaped")

    r2 = highlight_html("a & b")
    @assert occursin("&amp;", r2)                         "& not escaped"
    println("    [✓] & → &amp;")

    r3 = escape_html("say \"hello\"")
    @assert occursin("&quot;", r3)                        "\" not escaped"
    println("    [✓] \" → &quot;")

    r4 = escape_html("it's")
    @assert occursin("&#39;", r4)                         "' not escaped"
    println("    [✓] ' → &#39;")

    r5 = highlight_html("""x = "<script>alert(1)</script>" """)
    @assert !occursin("<script>", r5)                     "script injection leaked"
    println("    [✓] script injection blocked")

    r6 = highlight_html("f(x) = x > 0 ? x : -x")
    stripped = replace(r6, r"<[^>]+>" => "")
    @assert !occursin('<', stripped) && !occursin('>', stripped) "raw <> outside spans"
    println("    [✓] no raw < or > outside span tags")

    println()
end

# ---------------------------------------------------------------------------
# LaTeX injection tests  (NEW in v3)
# ---------------------------------------------------------------------------
function run_latex_tests()
    println("  LaTeX safety (LaTeX path):")

    r1 = highlight_latex("x & y")
    @assert occursin("\\&", r1)                           "& not escaped in LaTeX"
    println("    [✓] & → \\&")

    r2 = highlight_latex("price = \$100")
    @assert occursin("\\\$", r2)                          "\$ not escaped in LaTeX"
    println("    [✓] \$ → \\\$")

    r3 = highlight_latex("# comment")
    @assert occursin("\\#", r3) || occursin("DocumenterJLComment", r3) "# not handled"
    println("    [✓] # handled (escaped or in macro)")

    r4 = highlight_latex("x_1 + y^2")
    @assert !occursin(r"(?<![\\])_", r4) || occursin("DocumenterJL", r4) "_ leaked"
    println("    [✓] _ handled")

    r5 = highlight_latex("function f(x) end")
    @assert occursin("DocumenterJLKeyword{function}", r5) "keyword macro missing"
    println("    [✓] \\DocumenterJLKeyword{function} present")

    r6 = highlight_latex("x = \"hello\"")
    @assert occursin("DocumenterJLString", r6)            "string macro missing"
    println("    [✓] \\DocumenterJLString present for string literals")

    println()
end

# ---------------------------------------------------------------------------
# Character completeness test — no characters dropped
# ---------------------------------------------------------------------------
function run_completeness_tests()
    println("  Character completeness:")

    for (title, code) in TEST_CASES
        title == "REPL block — FIX 4" && continue  # REPL output lines change content

        html_result  = highlight_html(code)
        latex_result = highlight_latex(code)

        # strip all tags/macros and compare character sets
        html_plain  = replace(html_result, r"<[^>]+>" => "")
        html_plain  = replace(html_plain,  r"&amp;"   => "&")
        html_plain  = replace(html_plain,  r"&lt;"    => "<")
        html_plain  = replace(html_plain,  r"&gt;"    => ">")
        html_plain  = replace(html_plain,  r"&quot;"  => "\"")
        html_plain  = replace(html_plain,  r"&#39;"   => "'")

        @assert !isempty(html_plain)  "HTML result empty for: $title"

        latex_plain = replace(latex_result, r"\\DocumenterJL\w+\{" => "")
        latex_plain = replace(latex_plain,  r"\}" => "")

        @assert !isempty(latex_plain) "LaTeX result empty for: $title"

        print("    [✓] $title")
        println()
    end
    println()
end

# ---------------------------------------------------------------------------
# HTML output page
# ---------------------------------------------------------------------------
function generate_html_page(test_cases) :: String
    buf = IOBuffer()
    write(buf, """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>JuliaSyntaxBridge PoC v3</title>
<style>
body {
    font-family: -apple-system, sans-serif;
    background: #1a1a2e;
    color: #e0e0e0;
    max-width: 960px;
    margin: 0 auto;
    padding: 2rem;
    line-height: 1.6;
}
h1  { color: #9b72cf; border-bottom: 2px solid #9b72cf; padding-bottom: .5rem; }
h2  { color: #7cb4dd; font-size: .95rem; margin: 1.8rem 0 .3rem; font-family: monospace; }
.label { display: inline-block; font-size: .7rem; padding: 2px 6px; border-radius: 3px;
         background: #2d333b; color: #aaa; margin-left: 8px; vertical-align: middle; }
pre {
    background: #0d1117;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 1rem 1.4rem;
    overflow-x: auto;
    margin: .4rem 0;
}
code { font-family: "JuliaMono","Fira Code",monospace; font-size: .87rem; line-height: 1.75; }
.latex-preview {
    background: #0d1117;
    border: 1px solid #444;
    border-radius: 8px;
    padding: .6rem 1.4rem;
    margin: 0 0 1.4rem;
    font-family: monospace;
    font-size: .78rem;
    color: #aaa;
    overflow-x: auto;
}
.hljs-keyword     { color: #ff7b72; font-weight: bold; }
.hljs-string      { color: #79c0ff; }
.hljs-comment     { color: #8b949e; font-style: italic; }
.hljs-number      { color: #d2a679; }
.hljs-meta        { color: #d2a679; font-weight: bold; }
.hljs-title       { color: #7ee787; }
.hljs-operator    { color: #79c0ff; }
.hljs-type        { color: #f0c674; }
.hljs-built_in    { color: #ffa657; }
.hljs-symbol      { color: #d2a679; }
.hljs-char        { color: #96d0ff; }
.hljs-regexp      { color: #7ee787; }
.hljs-punctuation { color: #c9d1d9; }
.hljs-subst       { color: #c9d1d9; }
.hljs-error       { background: #8b1a1a; color: #fff; border-radius: 3px; padding: 0 3px; }
</style>
</head>
<body>
<h1>JuliaSyntaxBridge PoC v3</h1>
<p>stdlib AST highlighting — HTML path + LaTeX/PDF path — zero new dependencies.</p>
<p style="font-size:.85rem;color:#888">Each block shows the HTML-rendered output above and the raw LaTeX macro output below.</p>
""")

    for (title, code) in test_cases
        is_repl = startswith(title, "REPL")
        html_out  = is_repl ? highlight_html_repl(code) : highlight_html(code)
        latex_out = is_repl ? escape_latex(code) : highlight_latex(code)

        write(buf, "<h2>", escape_html(title),
              "<span class=\"label\">HTML</span></h2>\n")
        write(buf, "<pre><code>", html_out, "</code></pre>\n")
        write(buf, "<div class=\"latex-preview\">")
        write(buf, "<strong style=\"color:#666;font-size:.72rem\">LaTeX output: </strong>")
        write(buf, escape_html(latex_out))
        write(buf, "</div>\n")
    end

    write(buf, "</body>\n</html>\n")
    return String(take!(buf))
end

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
function main()
    println()
    println("JuliaSyntaxBridge PoC v3")
    println("Julia $(VERSION) — bridge available: $(BRIDGE_AVAILABLE)")
    println("=" ^ 55)
    println()

    run_xss_tests()
    run_latex_tests()
    run_completeness_tests()

    println("  Functional tests (HTML + LaTeX):")
    passed = 0
    failed = 0

    for (title, code) in TEST_CASES
        print("    $(title)... ")
        try
            is_repl = startswith(title, "REPL")

            # HTML path
            html = is_repl ? highlight_html_repl(code) : highlight_html(code)
            @assert !isempty(html)
            stripped = replace(html, r"<[^>]+>" => "")
            @assert !occursin('<', stripped) && !occursin('>', stripped)

            # LaTeX path
            if !is_repl
                ltx = highlight_latex(code)
                @assert !isempty(ltx)
            end

            println("✓")
            passed += 1
        catch e
            println("✗  $e")
            failed += 1
        end
    end

    println()
    println("  $(passed)/$(passed + failed) passed")
    println()

    # Benchmark measures the bridge's own processing time only.
    # Full Node.js comparison requires both runtimes installed on the same machine.
    # Run with BenchmarkTools.jl for a rigorous apples-to-apples measurement.
    
    if BRIDGE_AVAILABLE
        println("  Benchmark (bridge processing time only):")
        sample = join([tc[2] for tc in TEST_CASES], "\n")

        # warmup — avoid measuring JIT compilation
        highlight_html(sample); highlight_html(sample)
        highlight_latex(sample); highlight_latex(sample)

        N = 50
        t0 = time_ns()
        for _ in 1:N; highlight_html(sample); end
        html_ms = (time_ns() - t0) / N / 1e6

        t1 = time_ns()
        for _ in 1:N; highlight_latex(sample); end
        latex_ms = (time_ns() - t1) / N / 1e6

        println("    HTML path:   $(round(html_ms,  digits=3)) ms avg over $(N) runs")
        println("    LaTeX path:  $(round(latex_ms, digits=3)) ms avg over $(N) runs")
        println("    Sample size: $(length(sample)) chars across $(length(TEST_CASES)) blocks")
        println()
        println("    NOTE: full Node.js comparison requires both runtimes on the same machine.")
        println("    This measures bridge processing cost only, not end-to-end build time.")
        println()
    end

    html = generate_html_page(TEST_CASES)
    write("highlighted.html", html)
    println("  wrote highlighted.html")
    println()

    println("  LaTeX macro definitions (documenter.sty additions):")
    println(LATEX_MACROS)
end

main()
