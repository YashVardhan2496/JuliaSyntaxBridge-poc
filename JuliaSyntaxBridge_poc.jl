# JuliaSyntaxBridge_poc.jl — v4
# Run: julia JuliaSyntaxBridge_poc.jl → highlighted.html

const BRIDGE_AVAILABLE = isfile(
    joinpath(Sys.STDLIB, "JuliaSyntaxHighlighting", "src", "JuliaSyntaxHighlighting.jl")
)

if BRIDGE_AVAILABLE
    using JuliaSyntaxHighlighting
end

function get_face_annotations(code::String)::Vector
    BRIDGE_AVAILABLE || return []
    annotated = JuliaSyntaxHighlighting.highlight(code; syntax_errors=false)
    raw_anns  = Base.annotations(annotated)
    return [(ann.region, ann.value) for ann in raw_anns if ann.label === :face]
end

# All 46 faces verified against live runtime on Julia 1.12.5
const FACE_TO_CSS = Dict{Symbol,String}(
    :julia_macro                => "hljs-meta",
    :julia_symbol               => "hljs-symbol",
    :julia_singleton_identifier => "hljs-symbol",
    :julia_type                 => "hljs-type",
    :julia_typedec              => "hljs-type",
    :julia_comment              => "hljs-comment",
    :julia_string               => "hljs-string",
    :julia_regex                => "hljs-regexp",
    :julia_backslash_literal    => "hljs-string",
    :julia_string_delim         => "hljs-string",
    :julia_cmd                  => "hljs-string",
    :julia_cmd_delim            => "hljs-string",
    :julia_funcdef              => "hljs-title",
    :julia_opassignment         => "hljs-operator",
    :julia_char                 => "hljs-string",
    :julia_char_delim           => "hljs-string",
    :julia_number               => "hljs-number",
    :julia_bool                 => "hljs-number",
    :julia_funcall              => "hljs-title",
    :julia_broadcast            => "hljs-operator",
    :julia_builtin              => "hljs-built_in",
    :julia_operator             => "hljs-operator",
    :julia_comparator           => "hljs-operator",
    :julia_assignment           => "hljs-operator",
    :julia_keyword              => "hljs-keyword",
    :julia_parentheses          => "hljs-punctuation",
    :julia_unpaired_parentheses => "hljs-error",
    :julia_error                => "hljs-error",
    :julia_rainbow_paren_1      => "hljs-punctuation",
    :julia_rainbow_paren_2      => "hljs-punctuation",
    :julia_rainbow_paren_3      => "hljs-punctuation",
    :julia_rainbow_paren_4      => "hljs-punctuation",
    :julia_rainbow_paren_5      => "hljs-punctuation",
    :julia_rainbow_paren_6      => "hljs-punctuation",
    :julia_rainbow_bracket_1    => "hljs-punctuation",
    :julia_rainbow_bracket_2    => "hljs-punctuation",
    :julia_rainbow_bracket_3    => "hljs-punctuation",
    :julia_rainbow_bracket_4    => "hljs-punctuation",
    :julia_rainbow_bracket_5    => "hljs-punctuation",
    :julia_rainbow_bracket_6    => "hljs-punctuation",
    :julia_rainbow_curly_1      => "hljs-punctuation",
    :julia_rainbow_curly_2      => "hljs-punctuation",
    :julia_rainbow_curly_3      => "hljs-punctuation",
    :julia_rainbow_curly_4      => "hljs-punctuation",
    :julia_rainbow_curly_5      => "hljs-punctuation",
    :julia_rainbow_curly_6      => "hljs-punctuation",
)

const FACE_TO_LATEX = Dict{Symbol,String}(
    :julia_macro                => "DocumenterJLMacro",
    :julia_symbol               => "DocumenterJLSymbol",
    :julia_singleton_identifier => "DocumenterJLSymbol",
    :julia_type                 => "DocumenterJLType",
    :julia_typedec              => "DocumenterJLType",
    :julia_comment              => "DocumenterJLComment",
    :julia_string               => "DocumenterJLString",
    :julia_regex                => "DocumenterJLString",
    :julia_backslash_literal    => "DocumenterJLString",
    :julia_string_delim         => "DocumenterJLString",
    :julia_cmd                  => "DocumenterJLString",
    :julia_cmd_delim            => "DocumenterJLString",
    :julia_funcdef              => "DocumenterJLFunction",
    :julia_opassignment         => "DocumenterJLOperator",
    :julia_char                 => "DocumenterJLString",
    :julia_char_delim           => "DocumenterJLString",
    :julia_number               => "DocumenterJLNumber",
    :julia_bool                 => "DocumenterJLNumber",
    :julia_funcall              => "DocumenterJLFunction",
    :julia_broadcast            => "DocumenterJLOperator",
    :julia_builtin              => "DocumenterJLBuiltin",
    :julia_operator             => "DocumenterJLOperator",
    :julia_comparator           => "DocumenterJLOperator",
    :julia_assignment           => "DocumenterJLOperator",
    :julia_keyword              => "DocumenterJLKeyword",
    :julia_parentheses          => "DocumenterJLPunct",
    :julia_unpaired_parentheses => "DocumenterJLError",
    :julia_error                => "DocumenterJLError",
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

function escape_html(s::AbstractString)::String
    s = replace(s, "&"  => "&amp;")
    s = replace(s, "<"  => "&lt;")
    s = replace(s, ">"  => "&gt;")
    s = replace(s, "\"" => "&quot;")
    s = replace(s, "'"  => "&#39;")
    return s
end

function escape_latex(s::AbstractString)::String
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

function annotation_sort_key(ann)
    region = ann[1]
    return (first(region), -(last(region) - first(region)))
end

function emit_range_html(buf::IOBuffer, code::String, anns::Vector,
                         from::Int, to::Int, idx::Int)
    from > to && return
    pos = from
    i   = idx

    while i <= length(anns)
        region, face = anns[i]
        rstart = first(region)
        rend   = last(region)
        rstart > to && break

        if rstart > rend
            i += 1; continue
        end

        if rend > to
            pos < rstart && write(buf, escape_html(code[pos:prevind(code, rstart)]))
            write(buf, escape_html(code[rstart:to]))
            pos = nextind(code, to); i += 1; continue
        end

        pos < rstart && write(buf, escape_html(code[pos:prevind(code, rstart)]))

        j = i + 1
        while j <= length(anns)
            cr = anns[j][1]
            (first(cr) >= rstart && last(cr) <= rend) ? j += 1 : break
        end

        inner_buf = IOBuffer()
        emit_range_html(inner_buf, code, anns, rstart, rend, i + 1)
        inner = String(take!(inner_buf))
        isempty(inner) && (inner = escape_html(code[rstart:rend]))

        if haskey(FACE_TO_CSS, face)
            write(buf, "<span class=\"", FACE_TO_CSS[face], "\">", inner, "</span>")
        else
            write(buf, inner)
        end

        pos = nextind(code, rend)
        i   = j
    end

    pos <= to && write(buf, escape_html(code[pos:to]))
end

function emit_range_latex(buf::IOBuffer, code::String, anns::Vector,
                          from::Int, to::Int, idx::Int)
    from > to && return
    pos = from
    i   = idx

    while i <= length(anns)
        region, face = anns[i]
        rstart = first(region)
        rend   = last(region)
        rstart > to && break

        if rstart > rend
            i += 1; continue
        end

        if rend > to
            pos < rstart && write(buf, escape_latex(code[pos:prevind(code, rstart)]))
            write(buf, escape_latex(code[rstart:to]))
            pos = nextind(code, to); i += 1; continue
        end

        pos < rstart && write(buf, escape_latex(code[pos:prevind(code, rstart)]))

        j = i + 1
        while j <= length(anns)
            cr = anns[j][1]
            (first(cr) >= rstart && last(cr) <= rend) ? j += 1 : break
        end

        inner_buf = IOBuffer()
        emit_range_latex(inner_buf, code, anns, rstart, rend, i + 1)
        inner = String(take!(inner_buf))
        isempty(inner) && (inner = escape_latex(code[rstart:rend]))

        if haskey(FACE_TO_LATEX, face)
            write(buf, "\\", FACE_TO_LATEX[face], "{", inner, "}")
        else
            write(buf, inner)
        end

        pos = nextind(code, rend)
        i   = j
    end

    pos <= to && write(buf, escape_latex(code[pos:to]))
end

function highlight_html(code::String)::String
    !BRIDGE_AVAILABLE && return escape_html(code)
    anns = sort(get_face_annotations(code), by=annotation_sort_key)
    isempty(anns) && return escape_html(code)
    buf = IOBuffer()
    emit_range_html(buf, code, anns, firstindex(code), lastindex(code), 1)
    return String(take!(buf))
end

function highlight_html_repl(code::String)::String
    buf   = IOBuffer()
    lines = split(code, '\n')
    n     = length(lines)

    for (k, line) in enumerate(lines)
        line_s = String(line)
        suffix = k < n ? "\n" : ""

        if startswith(line_s, "julia> ")
            write(buf, "<span class=\"hljs-meta\">julia&gt;</span> ",
                  highlight_html(line_s[8:end]), suffix)
        elseif startswith(line_s, "       ") && !isempty(rstrip(line_s))
            write(buf, highlight_html(line_s), suffix)
        elseif startswith(line_s, "ERROR:")
            write(buf, "<span class=\"hljs-error\">", escape_html(line_s), "</span>", suffix)
        else
            write(buf, "<span class=\"hljs-comment\">", escape_html(line_s), "</span>", suffix)
        end
    end

    return String(take!(buf))
end

function highlight_latex(code::String)::String
    !BRIDGE_AVAILABLE && return escape_latex(code)
    anns = sort(get_face_annotations(code), by=annotation_sort_key)
    isempty(anns) && return escape_latex(code)
    buf = IOBuffer()
    emit_range_latex(buf, code, anns, firstindex(code), lastindex(code), 1)
    return String(take!(buf))
end

const TEST_CASES = [
    ("Basic function",
    """function greet(name::String)
    println("Hello, \$name")
    return nothing
end"""),

    ("Command strings",
    """cmd = `echo hello`
run(`ls -la /tmp`)
result = read(`git log --oneline`, String)"""),

    ("Macros",
    """@time begin
    result = @allocated sort(rand(1000))
    @assert result > 0
    @info "Done" result
end"""),

    ("String interpolation",
    """user = "Julia"
msg  = "Hello, \$(user)! Version \$(VERSION)."
cmd  = `echo \$msg`"""),

    ("Unicode identifiers",
    """α  = 0.01
∇f(x) = 2x
Δt    = 1e-3
x̄     = sum(α .* ∇f.(1:10)) * Δt"""),

    ("Number literals",
    """hex     = 0x1f3a
binary  = 0b1010_1100
octal   = 0o755
sci     = 1.5e-3
complex = 2 + 3im
big     = 1_000_000"""),

    ("Nested block comments",
    """#= outer
   #= inner =#
   still outer
=#
x = 42  # inline"""),

    ("Types and where clauses",
    """struct Container{T <: AbstractFloat}
    value :: T
    label :: String
end

function process(c::Container{T}) where {T}
    return c.value :: T
end"""),

    ("Parametric types",
    """d = Dict{String, Vector{Int}}()
push!(d, "key" => [1, 2, 3])"""),

    ("XSS attempt",
    """x = "<script>alert('xss')</script>"
y = a & b | c
z = x > 0 ? "yes" : "no\""""),

    ("LaTeX special chars",
    """# specials: & % \$ # _ { } ^ ~ \\
result = Dict{String,Int}("key" => 42)
formula = x^2 + y_1 ~ 0"""),

    ("Incomplete code",
    """function incomplete(x
    y = x +"""),

    ("REPL block",
    """julia> x = 1 + 2
3

julia> println("hello")
hello

ERROR: UndefVarError: z not defined"""),

    ("Face coverage",
    """flag = true
sym  = :mysymbol
pat  = r"[0-9]+"
cmd  = `echo hello`
x :: Int = 42"""),
]

function run_tests()
    println("  XSS safety:")
    r1 = highlight_html("<b>bold</b>")
    @assert !occursin("<b>", r1)                                "raw tags leaked"
    println("    [✓] tags escaped")

    r2 = highlight_html("a & b")
    @assert occursin("&amp;", r2)                               "& not escaped"
    println("    [✓] & → &amp;")

    r3 = highlight_html("""x = "<script>alert(1)</script>" """)
    @assert !occursin("<script>", r3)                           "script injection"
    println("    [✓] script injection blocked")

    r4 = highlight_html("f(x) = x > 0 ? x : -x")
    stripped = replace(r4, r"<[^>]+>" => "")
    @assert !occursin('<', stripped) && !occursin('>', stripped) "raw <> leaked"
    println("    [✓] no raw <> outside spans")

    println()
    println("  LaTeX safety:")
    r5 = highlight_latex("x & y")
    @assert occursin("\\&", r5)                                 "& not escaped"
    println("    [✓] & → \\&")

    r6 = highlight_latex("function f(x) end")
    @assert occursin("DocumenterJLKeyword{function}", r6)       "keyword macro missing"
    println("    [✓] \\DocumenterJLKeyword{function} present")

    println()
    println("  Character completeness:")
    for (title, code) in TEST_CASES
        startswith(title, "REPL") && continue
        html  = highlight_html(code)
        plain = replace(html, r"<[^>]+>" => "")
        plain = replace(plain, "&amp;" => "&", "&lt;" => "<",
                                "&gt;" => ">", "&quot;" => "\"", "&#39;" => "'")
        @assert plain == code "characters dropped in: $title"
        println("    [✓] $title")
    end

    println()
    println("  Functional:")
    passed = 0
    failed = 0

    for (title, code) in TEST_CASES
        print("    $title... ")
        try
            is_repl = startswith(title, "REPL")
            html    = is_repl ? highlight_html_repl(code) : highlight_html(code)
            @assert !isempty(html)
            stripped = replace(html, r"<[^>]+>" => "")
            @assert !occursin('<', stripped) && !occursin('>', stripped)
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
end

function generate_html_page(test_cases)::String
    buf = IOBuffer()
    write(buf, """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>JuliaSyntaxBridge v4</title>
<style>
body { font-family: -apple-system, sans-serif; background: #1a1a2e; color: #e0e0e0;
       max-width: 960px; margin: 0 auto; padding: 2rem; line-height: 1.6; }
h1   { color: #9b72cf; border-bottom: 2px solid #9b72cf; padding-bottom: .5rem; }
h2   { color: #7cb4dd; font-size: .95rem; margin: 1.8rem 0 .3rem; font-family: monospace; }
pre  { background: #0d1117; border: 1px solid #30363d; border-radius: 8px;
       padding: 1rem 1.4rem; overflow-x: auto; margin: .4rem 0; }
code { font-family: "JuliaMono","Fira Code",monospace; font-size: .87rem; line-height: 1.75; }
.latex-preview { background: #0d1117; border: 1px solid #444; border-radius: 8px;
                 padding: .6rem 1.4rem; margin: 0 0 1.4rem; font-family: monospace;
                 font-size: .78rem; color: #aaa; overflow-x: auto; }
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
.hljs-regexp      { color: #7ee787; }
.hljs-punctuation { color: #c9d1d9; }
.hljs-error       { background: #8b1a1a; color: #fff; border-radius: 3px; padding: 0 3px; }
</style>
</head>
<body>
<h1>JuliaSyntaxBridge v4</h1>
<p>AST-based highlighting — HTML + LaTeX — zero new dependencies.</p>
<p style="font-size:.8rem;color:#666">
  Julia $(VERSION) · BRIDGE_AVAILABLE = $(BRIDGE_AVAILABLE)
</p>
""")

    for (title, code) in test_cases
        is_repl   = startswith(title, "REPL")
        html_out  = is_repl ? highlight_html_repl(code) : highlight_html(code)
        latex_out = is_repl ? escape_latex(code) : highlight_latex(code)
        write(buf, "<h2>", escape_html(title), "</h2>\n")
        write(buf, "<pre><code>", html_out, "</code></pre>\n")
        write(buf, "<div class=\"latex-preview\">")
        write(buf, "<strong style=\"color:#555;font-size:.7rem\">LaTeX: </strong>")
        write(buf, escape_html(latex_out))
        write(buf, "</div>\n")
    end

    write(buf, "</body>\n</html>\n")
    return String(take!(buf))
end

function run_benchmark()
    !BRIDGE_AVAILABLE && return
    sample = join([tc[2] for tc in TEST_CASES], "\n")
    highlight_html(sample); highlight_html(sample)
    highlight_latex(sample); highlight_latex(sample)
    N  = 50
    t0 = time_ns()
    for _ in 1:N; highlight_html(sample); end
    html_ms = (time_ns() - t0) / N / 1e6
    t1 = time_ns()
    for _ in 1:N; highlight_latex(sample); end
    latex_ms = (time_ns() - t1) / N / 1e6
    println("  Benchmark (bridge processing only):")
    println("    HTML path:  $(round(html_ms,  digits=3)) ms avg over $N runs")
    println("    LaTeX path: $(round(latex_ms, digits=3)) ms avg over $N runs")
    println("    Sample:     $(length(sample)) chars · $(length(TEST_CASES)) blocks")
    println()
end

function main()
    println()
    println("JuliaSyntaxBridge v4")
    println("Julia $(VERSION) — bridge available: $(BRIDGE_AVAILABLE)")
    println("=" ^ 50)
    println()
    run_tests()
    run_benchmark()
    html = generate_html_page(TEST_CASES)
    write("highlighted.html", html)
    println("  wrote highlighted.html")
    println()
end

main()
