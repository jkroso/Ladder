# Tests for the colours of the parts of a line of code. See highlight.jl. Run
# them with `julia -O0 --project=. test/highlight_test.jl`.

@use Test: @test, @testset
@use "../code/highlight" tokens left_open

"Each part of `line` in `lang` as text => kind, without the plain parts that are only spaces"
parts(line, lang="julia", open='\0') = [t.text => t.kind for t in tokens(line, lang, open) if !(t.kind == :plain && all(isspace, t.text))]

"True when the tokens of `line` hold all of its characters, in order, at the right columns"
whole(line, lang="julia") = begin
  ts = tokens(line, lang)
  join(t.text for t in ts) == line && all(t.col == sum(length(u.text) for u in ts[1:k-1]; init=0) for (k, t) in enumerate(ts))
end

@testset "a string with no code in it is one part" begin
  @test parts("x = \"plain text\"") == ["x = " => :plain, "\"plain text\"" => :string]
  @test parts("\"costs \\\$5\"") == ["\"costs \\\$5\"" => :string]
  @test parts("\"a \$ b\"") == ["\"a \$ b\"" => :string]
end

@testset "code in a Julia string has the colours of code" begin
  @test parts("\"Clicked \$(c.count) times\"") ==
    ["\"Clicked " => :string, "\$(" => :keyword, "c.count" => :plain, ")" => :keyword, " times\"" => :string]
  @test parts("\"\$(round(Int, 100m.done))%\"") ==
    ["\"" => :string, "\$(" => :keyword, "round" => :call, "(" => :plain, "Int" => :type, ", " => :plain,
     "100" => :number, "m.done)" => :plain, ")" => :keyword, "%\"" => :string]
  @test parts("\"hello \$name!\"") == ["\"hello " => :string, "\$" => :keyword, "name!" => :plain, "\"" => :string]
  @test parts("\"\$x.y\"") == ["\"" => :string, "\$" => :keyword, "x" => :plain, ".y\"" => :string]
  @test parts("`ls \$dir`") == ["`ls " => :string, "\$" => :keyword, "dir" => :plain, "`" => :string]
end

@testset "a string in the code of a string" begin
  @test parts("\"a \$(join(xs, \", \")) b\"") ==
    ["\"a " => :string, "\$(" => :keyword, "join" => :call, "(xs, " => :plain, "\", \"" => :string,
     ")" => :plain, ")" => :keyword, " b\"" => :string]
  @test parts("\"\$(f(\"\$y\"))\"") ==
    ["\"" => :string, "\$(" => :keyword, "f" => :call, "(" => :plain, "\"" => :string, "\$" => :keyword,
     "y" => :plain, "\"" => :string, ")" => :plain, ")" => :keyword, "\"" => :string]
end

@testset "a Julia string with a name in front has no code" begin
  @test parts("colorant\"rgb(150,84,40)\"") == ["colorant" => :plain, "\"rgb(150,84,40)\"" => :string]
  @test parts("raw\"\$x\"") == ["raw" => :plain, "\"\$x\"" => :string]
  @test parts("r\"^\$\"") == ["r" => :plain, "\"^\$\"" => :string]
end

@testset "a string that doesn't close" begin
  @test parts("\"a \$(x") == ["\"a " => :string, "\$(" => :keyword, "x" => :plain]
  @test parts("\"a \$(x) b") == ["\"a " => :string, "\$(" => :keyword, "x" => :plain, ")" => :keyword, " b" => :string]
  @test parts("\"a \$") == ["\"a \$" => :string]
end

@testset "code in strings of other languages" begin
  @test parts("`Hi \${user.name}!`", "js") ==
    ["`Hi " => :string, "\${" => :keyword, "user.name" => :plain, "}" => :keyword, "!`" => :string]
  @test parts("\"Hi \${user.name}!\"", "js") == ["\"Hi \${user.name}!\"" => :string]
  @test parts("f\"{n + 1} {{x}}\"", "python") ==
    ["f" => :plain, "\"" => :string, "{" => :keyword, "n + " => :plain, "1" => :number, "}" => :keyword,
     " {{x}}\"" => :string]
  @test parts("f\"{(a + b)}\"", "python") ==
    ["f" => :plain, "\"" => :string, "{" => :keyword, "(a + b)" => :plain, "}" => :keyword, "\"" => :string]
  @test parts("\"{n}\"", "python") == ["\"{n}\"" => :string]
  @test parts("echo \"\$HOME/\${dir} \$(ls) \$1\"", "sh") ==
    ["echo" => :call, "\"" => :string, "\$" => :keyword, "HOME" => :plain, "/" => :string, "\${" => :keyword,
     "dir" => :plain, "}" => :keyword, " " => :string, "\$(" => :keyword, "ls" => :call, ")" => :keyword,
     " " => :string, "\$" => :keyword, "1" => :plain, "\"" => :string]
  @test parts("echo '\$HOME'", "sh") == ["echo" => :call, "'\$HOME'" => :string]
  @test parts("\"\$x\"", "rust") == ["\"\$x\"" => :string]
end

@testset "the tokens hold every character at its column" begin
  for (line, lang) in [("\"Clicked \$(c.count) times\"", "julia"), ("\"a \$(join(xs, \", \")) b\" # note", "julia"),
                       ("\"a \$(x", "julia"), ("\"α \$β γ\"", "julia"), ("`a \${`b \${c}`} d`", "js"),
                       ("f'{d[\"k\"]:>10}'", "python"), ("echo \"\${#arr[@]} \$?\"", "sh")]
    @test whole(line, lang)
  end
end

@testset "what was right before is still right" begin
  @test parts("x = 'a' # note") == ["x = " => :plain, "'a'" => :string, "# note" => :comment]
  @test parts("@def mutable struct Counter <: SemanticUI") ==
    ["@def" => :call, "mutable" => :keyword, "struct" => :keyword, "Counter" => :type, " <: " => :plain,
     "SemanticUI" => :type]
  @test parts("push!(xs, 0x1f)") == ["push!" => :call, "(xs, " => :plain, "0x1f" => :number, ")" => :plain]
end

@testset "a string in three quotes runs over several lines" begin
  # A docstring of several lines: the line that opens it leaves it open, and the lines inside it are all string
  @test left_open("\"\"\"", "julia") == '"' && left_open("f(x) = 1", "julia") == '\0'
  @test parts("Shows it for a time, to the end", "julia", '"') == ["Shows it for a time, to the end" => :string]
  @test left_open("Shows it for a time", "julia", '"') == '"'
  @test parts("", "julia", '"') == [] && left_open("", "julia", '"') == '"'
  # The line that closes it is string up to the three quotes, and code after them
  @test parts("the end\"\"\" f(x) = 2", "julia", '"') == ["the end\"\"\"" => :string, "f" => :call, "(x) = " => :plain, "2" => :number]
  @test left_open("the end\"\"\"", "julia", '"') == '\0' && left_open("\"\"\"", "julia", '"') == '\0'
  # Three quotes that close on their line, and two quotes, leave nothing open
  @test left_open("\"\"\"Short\"\"\"", "julia") == '\0' && parts("\"\"\"Short\"\"\"") == ["\"\"\"Short\"\"\"" => :string]
  @test left_open("x = \"\"", "julia") == '\0' && left_open("x = \"\"\"", "julia") == '"'
  # Three quotes in a comment or in a string of one quote open nothing, nor does an escaped quote close one
  @test left_open("# like \"\"\"", "julia") == '\0' && left_open("s = \"a \\\"\\\"\\\" b\"", "julia") == '\0'
  @test left_open("a \\\"\"\"\" b", "julia", '"') == '\0' && left_open("a \\\"\"\" b", "julia", '"') == '"'
  # Code in a docstring has the colours of code, as in a string of one line
  @test parts("costs \$(price) now", "julia", '"') == ["costs " => :string, "\$(" => :keyword, "price" => :plain, ")" => :keyword, " now" => :string]
  # Python has ''' as well. A language with no such strings leaves nothing open.
  @test left_open("'''", "python") == '\'' && parts("it's here", "python", '\'') == ["it's here" => :string]
  @test left_open("\"\"\"", "js") == '\0' && left_open("\"\"\"", "") == '\0'
  @test whole("the end\"\"\" g(\"x\")", "julia")
end

@testset "HTML" begin
  html(line, open='\0') = parts(line, "html", open)
  @test html("<a href=\"x.html\" hidden>Go &amp; see</a>") ==
    ["<a" => :keyword, "href" => :type, "=" => :plain, "\"x.html\"" => :string, "hidden" => :type, ">" => :keyword,
     "Go " => :plain, "&amp;" => :number, " see" => :plain, "</a" => :keyword, ">" => :keyword]
  @test html("<!doctype html> <!-- a note -->") == ["<!doctype" => :keyword, "html" => :type, ">" => :keyword, "<!--" => :comment, " a note -->" => :comment]
  @test whole("<p class='x'>a < b</p>", "html")
  # A comment and a tag can run over several lines
  @test left_open("<!-- starts here", "html") == '!' && html("still --> <b>", '!') == ["still -->" => :comment, "<b" => :keyword, ">" => :keyword]
  @test left_open("<meta name=\"a\"", "html") == '<' && html("  content=\"b\">", '<') == ["content" => :type, "=" => :plain, "\"b\"" => :string, ">" => :keyword]
  # The text of a <script> is JavaScript, and of a <style> CSS
  @test left_open("<script type=\"module\">", "html") == 'j'
  @test html("const x = 'a' // done", 'j') == ["const" => :keyword, " x = " => :plain, "'a'" => :string, "// done" => :comment]
  @test html("f(1) </script>", 'j') == ["f" => :call, "(" => :plain, "1" => :number, ") " => :plain, "</script" => :keyword, ">" => :keyword]
  @test left_open("const s = `one", "html", 'j') == 'b' && html("two` + 1", 'b') == ["two`" => :string, " + " => :plain, "1" => :number]
  @test left_open("x /* a", "html", 'j') == 'J' && left_open("b */ y", "html", 'J') == 'j'
  @test left_open("<style>", "html") == 'c'
  @test html("  .block { color: #a6c8e8; margin: 0 2px !important }", 'c') ==
    [".block" => :keyword, " { " => :plain, "color" => :type, ": " => :plain, "#a6c8e8" => :number, "; " => :plain, "margin" => :type, ": " => :plain,
     "0" => :number, "2px" => :number, "!important" => :keyword, " }" => :plain]
  @test html("  --ink: var(--ink-2); /* the text", 'c') == ["--ink" => :type, ": " => :plain, "var" => :call, "(--ink-2); " => :plain, "/* the text" => :comment]
  @test left_open("  /* Layout: a", "html", 'c') == 'C' && left_open("  b */", "html", 'C') == 'c' && left_open("</style> <p>", "html", 'c') == '\0'
end

"The parts of each of `lines`, a file in `lang`, as `parts` gives them. Each line starts in what the one above left open."
file(lines, lang) = begin
  open = '\0'
  map(lines) do line
    p = parts(line, lang, open)
    open = left_open(line, lang, open)
    p
  end
end

@testset "CSS" begin
  css(line, open='\0') = parts(line, "css", open)
  # A selector has the colour of a keyword, a property of a type, and in its value a number of a number
  @test css("a[href^=\"http\"]:not(.x) > p::before {") ==
    ["a" => :keyword, "[" => :plain, "href" => :type, "^=" => :plain, "\"http\"" => :string, "]" => :plain, ":not" => :keyword,
     "(" => :plain, ".x" => :keyword, ") > " => :plain, "p" => :keyword, "::before" => :keyword, " {" => :plain]
  @test css("  margin: -1px auto 0 !important;") ==
    ["margin" => :type, ": " => :plain, "-1px" => :number, " auto " => :plain, "0" => :number, "!important" => :keyword, ";" => :plain]
  @test css("  background: url(img/a.png) #fff;") ==
    ["background" => :type, ": " => :plain, "url" => :call, "(" => :plain, "img/a.png" => :string, ") " => :plain, "#fff" => :number, ";" => :plain]
  @test css("a{color:red;width:calc(100% - 2rem)}") ==
    ["a" => :keyword, "{" => :plain, "color" => :type, ":red;" => :plain, "width" => :type, ":" => :plain, "calc" => :call, "(" => :plain,
     "100%" => :number, " - " => :plain, "2rem" => :number, ")}" => :plain]
  @test css("@media screen and (min-width: 600px) {") ==
    ["@media" => :keyword, " screen " => :plain, "and" => :keyword, " (" => :plain, "min-width" => :type, ": " => :plain, "600px" => :number, ") {" => :plain]
  @test css("li:nth-child(2n+1) { display: none }") ==
    ["li" => :keyword, ":nth-child" => :keyword, "(" => :plain, "2n" => :number, "+" => :plain, "1" => :number, ") { " => :plain,
     "display" => :type, ": none }" => :plain]
  # A selector that goes on below, and a value that does
  @test file(["html,", "a:hover", "{ color: red }"], "css") ==
    [["html" => :keyword, "," => :plain], ["a" => :keyword, ":hover" => :keyword], ["{ " => :plain, "color" => :type, ": red }" => :plain]]
  @test file(["  font-family:", "    -apple-system,", "    \"Segoe UI\";", "  margin: 0;"], "css") ==
    [["font-family" => :type, ":" => :plain], ["    -apple-system," => :plain], ["\"Segoe UI\"" => :string, ";" => :plain],
     ["margin" => :type, ": " => :plain, "0" => :number, ";" => :plain]]
  # A value that lacks its ; ends where the next property starts
  @test file(["  color: red", "  margin: 0", "}"], "css")[2] == ["margin" => :type, ": " => :plain, "0" => :number]
  # A comment can run over several lines, among the rules or in a value
  @test left_open("/* a", "css") == 'C' && css("b */ p {", 'C') == ["b */" => :comment, "p" => :keyword, " {" => :plain]
  @test left_open("  color: /* a", "css") == 'V' && left_open("b */ red;", "css", 'V') == '\0'
  # Nothing is left open after a line that ends a rule or a property
  @test left_open("  color: red; }", "css") == '\0' && left_open("p {", "css") == '\0'
  @test whole("a[href^='x'] { b: url(\"q\") }", "css") && whole("p { a: b /* c", "css")
  # In CSS // doesn't start a comment
  @test css("  background: url(http://a.com/x.png);") ==
    ["background" => :type, ": " => :plain, "url" => :call, "(" => :plain, "http://a.com/x.png" => :string, ");" => :plain]
end

@testset "Less" begin
  less(line, open='\0') = parts(line, "less", open)
  # A variable that's set has the colour of a property, and // starts a comment
  @test less("@primary: #4a90e2; // the blue") ==
    ["@primary" => :type, ": " => :plain, "#4a90e2" => :number, "; " => :plain, "// the blue" => :comment]
  @test less("  border: @width solid darken(@primary, 10%);") ==
    ["border" => :type, ": @width solid " => :plain, "darken" => :call, "(@primary, " => :plain, "10%" => :number, ");" => :plain]
  # A mixin that's made has the colour of a selector, and one that's used the colour of a call
  @test less(".bordered(@width: 2px) {") ==
    [".bordered" => :keyword, "(" => :plain, "@width" => :type, ": " => :plain, "2px" => :number, ") {" => :plain]
  @test less("  .bordered(4px);") == [".bordered" => :call, "(" => :plain, "4px" => :number, ");" => :plain]
  @test less("  #ns > .clearfix;") == ["#ns" => :call, " > " => :plain, ".clearfix" => :call, ";" => :plain]
  @test less("  &:hover { color: red }") == ["&" => :keyword, ":hover" => :keyword, " { " => :plain, "color" => :type, ": red }" => :plain]
  # @{name} puts a variable's value in a selector or a string
  @test less(".@{name}-box { a: ~\"url(@{base})\" }") ==
    ["." => :plain, "@{" => :keyword, "name" => :plain, "}" => :keyword, "-box" => :keyword, " { " => :plain, "a" => :type, ": " => :plain,
     "~\"url(" => :string, "@{" => :keyword, "base" => :plain, "}" => :keyword, ")\"" => :string, " }" => :plain]
  # A guard, and rules like @import and @media, which a ( can follow
  @test less(".m(@a) when (iscolor(@a)) {") ==
    [".m" => :keyword, "(@a) " => :plain, "when" => :keyword, " (" => :plain, "iscolor" => :call, "(@a)) {" => :plain]
  @test less("@import (reference) \"x.less\";") == ["@import" => :keyword, " (reference) " => :plain, "\"x.less\"" => :string, ";" => :plain]
  @test less("@media(min-width: 768px) {")[1] == ("@media" => :keyword) && less("  @rules();") == ["@rules" => :call, "();" => :plain]
  # A // in a string isn't a comment, nor is a { in a comment a rule
  @test less("@url: \"http://a.com\"; // see { here }") ==
    ["@url" => :type, ": " => :plain, "\"http://a.com\"" => :string, "; " => :plain, "// see { here }" => :comment]
  @test left_open("@a: 1; // see {", "less") == '\0' && whole(".a { .m(); } // b", "less")
end

@testset "SCSS" begin
  scss(line, open='\0') = parts(line, "scss", open)
  # A variable that's set has the colour of a property, a flag like !default of a keyword, and // starts a comment
  @test scss("\$primary: #4a90e2 !default; // the blue") ==
    ["\$primary" => :type, ": " => :plain, "#4a90e2" => :number, "!default" => :keyword, "; " => :plain, "// the blue" => :comment]
  @test scss("  border: \$width solid darken(\$primary, 10%);") ==
    ["border" => :type, ": \$width solid " => :plain, "darken" => :call, "(\$primary, " => :plain, "10%" => :number, ");" => :plain]
  # The name of a mixin or a function that's made or used has the colour of a call
  @test scss("@mixin rounded(\$r: 4px) {") ==
    ["@mixin" => :keyword, "rounded" => :call, "(" => :plain, "\$r" => :type, ": " => :plain, "4px" => :number, ") {" => :plain]
  @test scss("  @include rounded;") == ["@include" => :keyword, "rounded" => :call, ";" => :plain]
  @test scss("  @include mixins.card(2px);") == ["@include" => :keyword, "mixins.card" => :call, "(" => :plain, "2px" => :number, ");" => :plain]
  # A selector like %name, which only @extend uses
  @test scss("%notice { color: red }") == ["%notice" => :keyword, " { " => :plain, "color" => :type, ": red }" => :plain]
  @test scss("  @extend %notice;") == ["@extend" => :keyword, "%notice" => :keyword, ";" => :plain]
  # #{...} puts a value in a selector or a string, and its code has the colours of a value
  @test scss(".icon-#{\$name} { content: \"#{\$i + 1}x\" }") ==
    [".icon-" => :keyword, "#{" => :keyword, "\$name" => :plain, "}" => :keyword, " { " => :plain, "content" => :type, ": " => :plain,
     "\"" => :string, "#{" => :keyword, "\$i + " => :plain, "1" => :number, "}" => :keyword, "x\"" => :string, " }" => :plain]
  @test scss("  background: url(#{\$base}/a.png);") ==
    ["background" => :type, ": " => :plain, "url" => :call, "(" => :plain, "#{" => :keyword, "\$base" => :plain, "}" => :keyword, "/a.png);" => :plain]
  # The words of rules that repeat or choose
  @test scss("@each \$name, \$glyph in \$icons {") == ["@each" => :keyword, " \$name, \$glyph " => :plain, "in" => :keyword, " \$icons {" => :plain]
  @test scss("@for \$i from 1 through 3 {") ==
    ["@for" => :keyword, " \$i " => :plain, "from" => :keyword, "1" => :number, "through" => :keyword, "3" => :number, " {" => :plain]
  @test scss("} @else if \$a == 2 {") == ["} " => :plain, "@else" => :keyword, "if" => :keyword, " \$a == " => :plain, "2" => :number, " {" => :plain]
  @test scss("\$x: if(\$a and \$b, 1, 2);") ==
    ["\$x" => :type, ": " => :plain, "if" => :call, "(\$a " => :plain, "and" => :keyword, " \$b, " => :plain, "1" => :number, ", " => :plain,
     "2" => :number, ");" => :plain]
  @test scss("@use \"sass:math\" as m;") == ["@use" => :keyword, "\"sass:math\"" => :string, "as" => :keyword, " m;" => :plain]
  # A map over several lines: its keys have the colour of a property
  @test file(["\$sizes: (", "  small: 576px,", "  large: 992px", ");"], "scss") ==
    [["\$sizes" => :type, ": (" => :plain], ["small" => :type, ": " => :plain, "576px" => :number, "," => :plain],
     ["large" => :type, ": " => :plain, "992px" => :number], [");" => :plain]]
  @test left_open("\$sizes: (", "scss") == 'v' && left_open(");", "scss", 'v') == '\0'
  @test whole("@use \"sass:math\" as m; .a-#{\$b} { c: m.div(1, 2) \"#{d}\" } // e", "scss")
  # In CSS, a $ is nothing special
  @test parts("a: \$b;", "css") == ["a" => :type, ": \$b;" => :plain]
end

@testset "Julia's REPL" begin
  repl(line, open='\0') = parts(line, "julia-repl", open)
  # A prompt has the colour of a keyword, the code after julia> the colours of Julia, and what it printed is one colour
  @test repl("julia> f(x) = 1") == ["julia>" => :keyword, "f" => :call, "(x) = " => :plain, "1" => :number]
  @test file(["julia> function f(x)", "           x + 1", "       end", "f (generic function with 1 method)"], "julia-repl") ==
    [["julia>" => :keyword, "function" => :keyword, "f" => :call, "(x)" => :plain], ["    x + " => :plain, "1" => :number],
     ["end" => :keyword], ["f (generic function with 1 method)" => :plain]]
  @test left_open("julia> 1 + 1", "julia-repl") == 'i' && left_open("2", "julia-repl", 'i') == 'o' && repl("2", 'i') == ["2" => :plain]
  # Other prompts
  @test repl("shell> ls \"\$HOME\"") == ["shell>" => :keyword, "ls" => :call, "\"" => :string, "\$" => :keyword, "HOME" => :plain, "\"" => :string]
  @test repl("(@v1.12) pkg> add DataFrames") == ["(@v1.12) pkg>" => :keyword, "add DataFrames" => :plain]
  @test repl("help?> sum") == ["help?>" => :keyword, "sum" => :plain] && repl("julia>") == ["julia>" => :keyword]
  # A docstring in the code goes on in the lines below
  @test left_open("julia> \"\"\"", "julia-repl") == 'I' && repl("       Adds one", 'I') == ["Adds one" => :string]
  # A block in a list has spaces before its prompts
  @test file(["    julia> x = 1", "           + 2", "    3"], "jldoctest") ==
    [["julia>" => :keyword, "x = " => :plain, "1" => :number], ["    + " => :plain, "2" => :number], ["    3" => :plain]]
  # A line with no prompt at the start of a julia-repl block is what some code printed
  @test repl("a = 1") == ["a = 1" => :plain]
  # A jldoctest block, whose fence can have more after the name, can be a script that ends with # output
  @test parts("julia> x", "jldoctest;") == ["julia>" => :keyword, "x" => :plain]
  @test file(["a = 1", "", "# output", "", "1"], "jldoctest") == [["a = " => :plain, "1" => :number], [], ["# output" => :comment], [], ["1" => :plain]]
  @test whole("julia> x = \"a\" # b", "julia-repl") && whole("       y", "julia-repl")
end

@testset "diffs" begin
  @test file(["diff --git a/x.jl b/x.jl", "index 1a2b..3c4d 100644", "--- a/x.jl", "+++ b/x.jl", "@@ -1,2 +1,2 @@ f(x) =",
              " same", "-old", "+new", "\\ No newline at end of file"], "diff") ==
    [["diff --git a/x.jl b/x.jl" => :keyword], ["index 1a2b..3c4d 100644" => :comment], ["--- a/x.jl" => :keyword], ["+++ b/x.jl" => :keyword],
     ["@@ -1,2 +1,2 @@" => :type, " f(x) =" => :plain], [" same" => :plain], ["-old" => :removed], ["+new" => :added],
     ["\\ No newline at end of file" => :comment]]
  # A line taken away that starts with --- is still a line taken away, as in a block written by hand
  @test parts("--- a heading", "diff") == ["--- a heading" => :removed] && parts("- old", "patch") == ["- old" => :removed]
  @test parts("--- old.txt\t2026-11-21 10:00", "diff") == ["--- old.txt\t2026-11-21 10:00" => :keyword]
  @test parts("@@ -1 +1 @@", "diff") == ["@@ -1 +1 @@" => :type] && whole("@@ -1 +1 @@ end", "diff") && parts("", "diff") == []
end

@testset "JSON Lines, and JSON with comments" begin
  @test parts("{\"a\": 1, \"b\": null}", "jsonl") ==
    ["{" => :plain, "\"a\"" => :string, ": " => :plain, "1" => :number, ", " => :plain, "\"b\"" => :string, ": " => :plain, "null" => :number, "}" => :plain]
  @test parts("{\"a\": 1} // see \"x\"", "jsonc") == ["{" => :plain, "\"a\"" => :string, ": " => :plain, "1" => :number, "} " => :plain, "// see \"x\"" => :comment]
  @test parts("{\"url\": \"http://a.com\"}", "json5") == ["{" => :plain, "\"url\"" => :string, ": " => :plain, "\"http://a.com\"" => :string, "}" => :plain]
end

@testset "shells" begin
  sh(line, open='\0') = parts(line, "bash", open)
  # The name of a command has the colour of a call, and a number only when it's a whole word
  @test sh("cd suppliers/x && git add -A") == ["cd" => :call, " suppliers/x && " => :plain, "git" => :call, " add -A" => :plain]
  @test sh("magick raw-05.png -resize 2000x 2>/dev/null") ==
    ["magick" => :call, " raw-05.png -resize 2000x " => :plain, "2" => :number, ">/dev/null" => :plain]
  @test sh("myapp --threads=2 src/JobDetail/Card.tsx") == ["myapp" => :call, " --threads=" => :plain, "2" => :number, " src/JobDetail/Card.tsx" => :plain]
  # A variable has the same colours outside a string as in one
  @test sh("tar -C \$dir \${#arr[@]} \$(ls)") ==
    ["tar" => :call, " -C " => :plain, "\$" => :keyword, "dir " => :plain, "\${" => :keyword, "#arr[@]" => :plain, "}" => :keyword,
     "\$(" => :keyword, "ls" => :call, ")" => :keyword]
  # Keywords, a variable that's set for a command, and a # inside a word, which doesn't start a comment
  @test sh("if [ -f x ]; then PORT=9101 julia a#b.jl; fi # done") ==
    ["if" => :keyword, " [ -f x ]; " => :plain, "then" => :keyword, " PORT=" => :plain, "9101" => :number, "julia" => :call,
     " a#b.jl; " => :plain, "fi" => :keyword, "# done" => :comment]
  @test sh("sudo git pull | xargs -0 rm") == ["sudo" => :call, "git" => :call, " pull | " => :plain, "xargs" => :call, " -0 " => :plain, "rm" => :call]
  # A here-document is a string, up to the line with the word that ends it
  @test file(["cat > a.toml << 'EOF'", "name = \"x\"", "EOF", "ls"], "bash") ==
    [["cat" => :call, " > a.toml << " => :plain, "'EOF'" => :string], ["name = \"x\"" => :string], ["EOF" => :string], ["ls" => :call]]
  @test file(["git commit -m \"\$(cat <<'EOF'", "Fix it", "EOF", ")\""], "bash")[2:3] == [["Fix it" => :string], ["EOF" => :string]]
  @test left_open("cat <<<\"x\"", "bash") == '\0' && left_open("echo '<<EOF'", "bash") == '\0' && left_open("x # <<EOF", "bash") == '\0'
  # A line that ends with \ goes on below, where the first word isn't a command
  @test file(["docker run \\", "  -p 80:80 nginx"], "bash")[2] == ["  -p " => :plain, "80:80" => :number, " nginx" => :plain]
  # A prompt: in a bash block a $ at the start, and in a console block a line with no prompt is what a command printed
  @test sh("\$ julia --project=. x.jl") == ["\$" => :keyword, "julia" => :call, " --project=. x.jl" => :plain]
  @test file(["\$ ls -l", "a.txt", "% echo hi"], "console") ==
    [["\$" => :keyword, "ls" => :call, " -l" => :plain], ["a.txt" => :plain], ["%" => :keyword, "echo" => :call, " hi" => :plain]]
  @test whole("x=\$(echo \"a \$(b) c\") # d", "bash") && whole("❯ ls", "console") && whole("a \\", "zsh")
end

@testset "Kate's definitions" begin
  # Ruby, Lua and Makefile get their colours from the XML files in syntax/, by their names or their files' ends
  @test parts("class Greeter < Base", "ruby") == ["class" => :keyword, "Greeter" => :type, " < " => :plain, "Base" => :type]
  @test parts("  attr_reader :name", "rb") == ["attr_reader" => :type, ":name" => :number]
  @test parts("@x.map { |v| v.upcase } # done", "ruby") ==
    ["@x" => :type, "." => :plain, "map" => :call, " { |v| v." => :plain, "upcase" => :call, " } " => :plain, "# done" => :comment]
  @test parts("local t = { x = 1, [\"y\"] = 2.5 } -- note", "lua") ==
    ["local" => :keyword, " t = { x = " => :plain, "1" => :number, ", [" => :plain, "\"y\"" => :string, "] = " => :plain, "2.5" => :number,
     " } " => :plain, "-- note" => :comment]
  @test parts("CC ?= clang", "makefile") == ["CC" => :type, "?= clang" => :string]
  @test parts("\t\$(CC) -o \$@ \$^", "mk") == ["\$(" => :string, "CC" => :type, ")" => :string, " -o " => :plain, "\$@" => :string, "\$^" => :string]
  # What runs over several lines: a here-document of Ruby, a long comment of Lua, a Makefile's rule
  @test file(["text = <<~EOS", "  Dear you", "EOS", "x = 1"], "ruby") ==
    [["text = <<~" => :plain, "EOS" => :keyword], ["  Dear you" => :string], ["EOS" => :keyword], ["x = " => :plain, "1" => :number]]
  @test file(["--[[ a long", "comment ]] x = 1"], "lua") == [["--[[ a long" => :comment], ["comment ]]" => :comment, " x = " => :plain, "1" => :number]]
  @test file(["all: app", "\tcc -o app main.c", "clean:"], "Makefile") ==
    [["all:" => :number, " " => :type, "app" => :string], ["\tcc -o app main.c" => :plain], ["clean:" => :number]]
  @test left_open("--[[ a", "lua") != '\0' && left_open("]]", "lua", left_open("--[[ a", "lua")) == '\0'
  @test whole("def f(x) = \"#{x}\" # é", "ruby") && whole("print('ü') --[[ x", "lua")
  # More of Kate's languages. A block of PHP needs no <?php, a .m file is Objective-C, and Nim's operators are plain.
  @test parts("\$x = array(1, 2); return \$x; // note", "php") ==
    ["\$x = " => :plain, "array" => :type, "(" => :plain, "1" => :number, ", " => :plain, "2" => :number, "); " => :plain, "return" => :keyword,
     " \$x; " => :plain, "// note" => :comment]
  @test parts("@interface Foo : NSObject // a class", "m") == ["@interface" => :keyword, " Foo : NSObject " => :plain, "// a class" => :comment]
  @test parts("[core]", "ini") == ["[core]" => :keyword] && parts("editor = vim", "ini") == ["editor =" => :type, " vim" => :string]
  @test parts("FROM julia:1.12 AS build # base", "dockerfile") ==
    ["FROM" => :keyword, " julia:1.12 " => :plain, "AS" => :keyword, " build " => :plain, "# base" => :comment]
  @test parts("let rec f n = n (* f *)", "ocaml") == ["let" => :keyword, "rec" => :keyword, " f n = n " => :plain, "(* f *)" => :comment]
  @test parts("proc greet(name: string): string = name", "nim") ==
    ["proc" => :keyword, "greet" => :call, "(name: " => :plain, "string" => :type, "): " => :plain, "string" => :type, " = name" => :plain]
  @test parts("msgid \"Hello\"", "po") == ["msgid" => :keyword, "\"Hello\"" => :string]
  @test parts("my \$x = shift; # note", "perl") == ["my" => :keyword, "\$x" => :type, " = " => :plain, "shift" => :call, "; " => :plain, "# note" => :comment]
  # A language that's neither here nor in syntax/ is one colour
  @test parts("anything at all", "cobol") == ["anything at all" => :plain]
end
