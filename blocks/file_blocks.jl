# Kinds of block that a file defines: a code block in a language that isn't one of Ladder's own

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "../markdown" Kind classify MATTER TOML_MATTER MATH
@use "../markdown" COMMENT
@use "../code/guard" => Guard
@use "../base" exports...
@use "../page/page_extras" exports...
@use "../code/sandbox" exports...

export DEFINES, PAGES_RUN, SOURCE, defines, page_module_name, run_page!

# --- blocks that a file defines --------------------------------------------------------------
#
# A page can have kinds of block that Ladder doesn't know. A code block in a
# language that isn't one of Ladder's own, like `progress`, is such a block
# when a file defines the language. The file is `progress.jl` in the page's
# folder, or the file or the GitHub repository that the line that opens the
# block names after the language:
#
#     ```progress                             progress.jl, beside the page
#     ```progress ./widgets.jl                a file that has another name
#     ```progress github.com/sam/blocks       a repository on GitHub
#     ```progress github.com/sam/blocks@v2    one branch of it
#
# The file can be a Markdown page too: `progress.md` beside the page, when
# there's no `progress.jl`, or a path that ends in `.md`. Ladder runs the code
# of the page's `julia` blocks, from the top, in one module, and that module
# defines the kind of block as a Julia file's module does. So the page can say
# in words what its code does, and can hold a block of its own kind to try.
#
# A file beside the page only counts if its text defines a function with the
# language's name that takes one thing. So a page in a folder of Julia code
# doesn't run `json.jl` because it has a block of JSON.
#
# The file has a function with the language's name. Ladder gives it the lines
# of the block, and shows what it makes, as a `ui` block shows what its code
# makes: a node draws itself, and any other value shows as text. If the file
# also has a function called `written`, it gives the lines of what was made,
# and Ladder writes them into the block. So what you do to the block is in
# the page's file.
#
#     progress(lines)          makes a Progress from the lines of the block
#     describe(p::Progress)    draws it
#     written(p::Progress)     the lines of its block now
#
# There are three times that Ladder writes a block's lines:
#
#   - Before something reads the page's text: ⌘S, the caret going into the
#     block, a copy, a page of HTML, another page taking the window. The file
#     does nothing for this.
#   - When the component asks, with UI.jl's `changed!(p)`. Ladder writes in
#     the next frame that the mouse isn't held in. Changes that come one soon
#     after another are one step for ⌘Z.
#   - At once, when the component says `changed!(p, now=true)`.
#
# A change that's written only by the first of these doesn't mark the page as
# edited until then, and ⌘Z can't take it back. So a component asks for a
# write after each change that you'd want to take back.
#
# What was made is kept until the block's lines change some other way: you
# type in them, or ⌘Z puts back older ones. Then the function makes it again.
#
# Ladder asks you before it runs the code of a GitHub repository for the
# first time, and keeps the repositories that you allow in a file.
#
# A file on this Mac is loaded again when it's saved, so a kind of block
# changes as you write it. Each block that the file defines is then made again.

"The file or the repository that follows the language on the line that opens a code block"
const SOURCE = r"^\s*(?:`{3,}|~{3,})\s*[^\s`]+[ \t]+((?:\.{1,2}/|~?/|github\.com/)\S+)\s*$"

"True when Ladder itself says what a code block in the language `lang` shows"
known_lang(lang) = lang in (MATTER, TOML_MATTER, MATH, HEX, BITS, COMMENT, "julia") || haskey(BLOCKS, lang)

"What was found in each file that could define a kind of block: when the file was saved, and whether its text defines the function"
const DEFINES = Dict{Tuple{String,String},Tuple{Float64,Bool}}()

"""
True when the text of `file` defines a function called `name` that takes one
thing, like `progress(lines) = ...` or `function progress(lines)`. The file
is read again only when it's saved.
"""
defines(file::AbstractString, name::AbstractString) = begin
  at = mtime(file)
  at == 0 && return false
  kept = get(DEFINES, (file, name), nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  code = ismarkdown(file) ? join(last.(page_code(file)), "\n") : read(file, String)
  found = occursin(Regex("^(?:function[ \\t]+)?\\Q$name\\E\\([^,;)]+[;)]", "m"), code)
  DEFINES[(file, name)] = (at, found)
  found
end

"""
Where the function of a block in the language `lang` comes from, as Kip names
it: a file or a GitHub repository. `text` is the line that opens the block, and
`folder` is the folder of its page. It's nothing when no file defines the language.
"""
block_source(text::AbstractString, lang::AbstractString, folder::AbstractString) = begin
  (Base.isidentifier(lang) && !known_lang(lang)) || return nothing
  m = match(SOURCE, text)
  m === nothing || return String(m[1])
  isempty(folder) && return nothing
  # A Julia file comes before a Markdown page with the same name
  k = findfirst(ext -> defines(joinpath(folder, lang * ext), lang), (".jl", ".md"))
  k === nothing ? nothing : "./$lang$((".jl", ".md")[k])"
end

"The pages whose code has all run in their module, by path, as the kinds of block that a page defines need"
const PAGES_RUN = Set{String}()

"The name of the module of the page at `path`: its path, with ~ for your home folder, and a ⭒ in front, as Kip's modules have"
page_module_name(path::AbstractString) = Symbol("⭒", Base.Filesystem.contractuser(page_key(path)))

"The code of each `julia` block of the Markdown page at `path`, with the line of the page that it starts on. `lines` are the page's lines."
page_code(path::AbstractString, lines=text(path)) = begin
  ks = classify(lines)
  out = Tuple{Int,String}[]
  for (i, k) in enumerate(ks)
    (k.kind == Kind.fence && k.level == 0 && k.lang == "julia") || continue
    t = something(findnext(c -> c.kind == Kind.fence, ks, i + 1), length(lines) + 1)
    push!(out, (i + 1, join(lines[i+1:t-1], "\n")))
  end
  out
end

"""
Run the code of the Markdown page at `path` in the module `m`: each of its
`julia` blocks, from the top. An error names the line of the page that it's on.
"""
run_page!(m::Module, path::AbstractString) = (page_value(m, path); m)

"""
Run the code of the Markdown page at `path` in the module `m`, as `run_page!`
does. It gives the value of the last `julia` block, or nothing when the page
has none. `lines` are the page's lines, as a page from a web server gives them.
"""
page_value(m::Module, path::AbstractString, lines=text(path)) = begin
  value = nothing
  for (line, code) in page_code(path, lines)
    try
      # Empty lines before the code give each line of it the number that it has in the page
      value = run_in(m, "\n"^(line - 1) * code, path)
    catch err
      error("Line $(err isa LoadError ? err.line : line) of $(basename(path)): $(trouble(err))")
    end
  end
  value
end

"""
Run the code `code` of the page at `path` in the page's module `m`, as
`include_string` does, and give the value that it comes to. A function that
the code defines with the name of a unit, like `bar(p) = …`, is a new function
of the page. Julia gives a unit that new method instead: a unit is a type, and
a page has the units with `using`, so Julia takes the code as a new way to make
the unit. A name that the page loads or makes itself is as Julia has it.
"""
run_in(m::Module, code::AbstractString, path::AbstractString) = begin
  # The code of a page from a site that you don't trust runs in the sandbox: see "the sandbox" in sandbox.jl
  c = sandbox_of(m, path)
  c === nothing ? include_string(ex -> own_units(m, ex), m, code, path) : Guard.run_code(c, code, path; map=ex -> own_units(m, ex))
end
