# Sums in a line of text

A sum can go in a line of text: a `!`, and then the sum between backticks. The page shows what the sum comes to. A sum that is only a number has a line of dashes under it, and the user drags it to change it. Each sum that uses its name follows while the mouse moves. Use it to explain how numbers depend on each other, in sentences.

```
A wall that is !`l = 16m` long and !`h = 2.4m` high has an area of !`wall_area = l * h`.
Two coats of paint that covers !`per_litre = 16m²` a litre take !`wall_area * 2 / (per_litre / litre)`.
```

- A name of a sum is a Julia name, like `wall_area`. A later sum uses it.
- A sum can use the rows of each sheet of the page, with a `_` for each space: `` !`wall_length` ``. A sheet under the sum can use the sum's name, with a space for each `_`.
- A sum can give words: `` !`farm_cost > 2e9USD ? "it needs more than one company" : "one company can pay"` ``.
- The units are those of Units.jl: `m`, `km`, `ft`, `inch`, `s`, `minute`, `hr`, `kg`, `litre`, `kW`, `GW`, `kWh`, `TWh`, and money like `USD`, `AUD` and `EUR`. A sheet has the same units.
- A cell of a table can hold a sum, and a `chart` of the table draws what the sums show.
