# Code that runs where it is

Put the caret in a line of code and press ⌘Return. The page runs the line, and shows what it comes to in a box after the line. ⇧Return runs the line and goes to the next one, so you can go down a block with it.

```julia
width = 2.4
height = 3.6
area = width * height
```

## An expression of several lines

The caret can be in any line of the expression, or in the comment above it.

```julia
# The paint for a wall, in litres, at 12 square metres to the litre
paint(area; coats=2) = begin
  coats * area / 12
end

paint(area)
```

## A value with more to show

A box with an arrow has more than its first line. Click the box to show the rest, and click it again to hide it.

```julia
grid = [row * column for row in 1:4, column in 1:6]
Dict("wall" => area, "paint" => paint(area))
rand(40, 40)
```

## What the code prints, and what goes wrong

Text that the code prints shows in the box. What goes wrong shows in red. Code that ends with a semicolon shows a tick and no value.

```julia
println("The wall is ", area, " square metres")
sqrt(-1)
total = sum(grid);
```

## Names

Type the first two letters of a name that the page's code has, like `ar` or `pa`, on the empty line of this block. A list under the caret shows the names that start that way. ↑ and ↓ choose one, Return or Tab types the rest of it, and Escape hides the list.

The list has only the names that code at the caret can use. A name that's made inside a function, like a value that the function takes, is in the list only while the caret is in that function. The fields of a struct are never in it.

Each name has paler words at its right that say what it is. A name with a value says the type of the value, like `Float64` or `Vector{Wall}`. Other names say `function`, `struct`, `module` or `macro`. The page reads these from its code, so most names have them before any code has run.

```julia
area
```

## What a function takes

Run the first block of this page, then type `paint(` on the empty line of this block. A box under the line lists what the function takes, with one line for each of its methods. The value that the caret is at has a line under it, and a value in square brackets can be left out.

- The box goes when you start to type a value. It comes back after the comma, for the next value.
- The box closes when the caret leaves the brackets. Escape hides it.
- Go back into a call and type a comma or a semicolon. The box opens for the next value.
- Type the start of a name that the function gives a value, like `co` for `coats`. The list of names has `coats=` first. After a semicolon the list has only such names, from the first letter. Each has the type of its value at its right, and the value that it has when you leave it out, like `Int64 = 2`.
- A function of the page has a box after its code has run. Julia's own functions, like `round(`, always have one.
- After the first value, only the methods that can take one more value stay in the box.

```julia
paint(area)
```

## Brackets and quotes

Type `(`, `[`, `{` or `"` in code, and the one that closes it comes too. The caret stays between the two. This is so in every code block and in a file of code.

- Type the closing bracket where it already is, and the caret goes over it. So `f(x)` typed one key after another is `f(x)`.
- Select some text and type a bracket or a quote. The pair goes round the text.
- Press ⌫ between the two of a pair that has nothing in it, and both go.
- Before a word, a bracket comes alone. A quote that ends a string comes alone too.
- Type `"` three times for the six quotes of a string of several lines.

The two brackets that the caret is between glow, so you can see where a bracket closes. The two can be on different lines. Put the caret after the `[` in this block to try it.

```julia
sizes = [round(2.4 * 3.6, digits=1),
         round(1.2 * 0.9, digits=1)]
```

## Functions and modules

The box of a function opens to show the function's documentation and a table of its methods. The box of a module opens to show the module's readme, or its documentation, and a table of the names that it defines. Type in the field over that table to search the names. The wheel moves through an open box.

```julia
length
Base.Iterators
```

## Structs

The box of a struct opens to show a line for each of the struct's fields: the field's name and its value. A line with an arrow has a value that has parts of its own. Click the line to show them under it, and click it again to hide them.

```julia
struct Wall
  long::Float64
  name::String
end
struct Room
  walls::Vector{Wall}
  door::Wall
end
Room([Wall(4.2, "north"), Wall(3.0, "east")], Wall(0.9, "door"))
```

## Under the value

Each block of code has levels under the value of what it runs. Put the caret in the block below and run its two lines. Then hold the mouse over the ladder at the top right. It opens into a slider with four stops. At the top stop, a box shows the value. One stop down, it shows the code as Julia infers it, with the type of each step. Under that it shows the LLVM code, and under that the assembly. ⌘E goes between the value and the inferred code.

```julia
half(x) = x / 2
half(9)
```

Each block keeps its own level, and the slider is about the block that the caret is in. With the caret in the text of the page, the slider is the page's again.

## The whole block, a selection and a node

Put the caret in the line that opens a block, the one with the three backticks, and ⌘Return runs every line of the block. Select part of a line, like `1:6` in the grid above, and ⌘Return runs that part alone.

A value that's a part of a window shows as itself. Run this line and drag the slider. In a file of code, like `widgets.jl`, such a value doesn't show as itself. Its box lists its fields, and then its children.

```julia
Slider(value=0.4)
```

A box goes when you change its code. Escape takes every box off the page.
