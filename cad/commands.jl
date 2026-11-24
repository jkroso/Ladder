# What the design editor knows of SolidCraft's commands: the form that each
# one fills in, the sketch tools that take clicks, and where each command is
# in the toolbar.
#
# SolidCraft has about 640 commands, and its program lists them all
# (`list_commands`). A command takes its parameters as JSON, like
#
#     solid.fillet  {"edges": [[30, 22.5, 6]], "radius": "2 mm"}
#
# A `Spec` says how the editor asks for those: a `Field` for each parameter,
# with the kind of thing it is. A length is typed. A face, an edge or a region
# of a sketch is clicked in the design. `params(spec, values)` then makes the
# JSON that SolidCraft takes.
#
# The commands that are used most have a form written here by hand. For any
# other command, `spec(command)` makes a form from what SolidCraft says of its
# parameters, so every command can be run from the editor.

@use "./json" => JSON
@use "./json" Object

"One thing that a form asks for"
struct Field
  key::String                     # the name of the parameter
  label::String
  kind::Symbol                    # :length :angle :count :text :json :choice :flag :vector, or what's clicked: :faces :face :edges :bodies :body :profiles :plane :spot
  default::Any
  options::Vector{Pair{Any,String}}   # for a :choice: each value that's sent, and what the form calls it
  optional::Bool
  section::Any                    # the part of the form that it's in, or nothing for the part that suits its kind: see `section`
end
Field(key, label, kind; default=kind == :flag ? false : "", options=Pair{Any,String}[], optional=false, section=nothing) =
  Field(key, label, kind, default, Pair{Any,String}[o for o in options], optional, section)
Field(key, label, kind, default, options, optional) = Field(key, label, kind, default, options, optional, nothing)

"""
The part of a form that the field `f` is in. SolidCraft's forms have three:
what the command needs is first, with no name. What can be ticked is under
Options. What's seldom changed is under Advanced, which is closed at first.
"""
section(f::Field) = f.section !== nothing ? f.section : f.kind == :flag ? "Options" : f.optional ? "Advanced" : ""

"True for a field that's filled by clicks in the design"
picks(f::Field) = f.kind in (:faces, :face, :edges, :bodies, :body, :profiles, :plane, :spot)
"True for a field that takes any number of clicks"
many(f::Field) = f.kind in (:faces, :edges, :bodies, :profiles)

"The form of a command"
struct Spec
  command::String
  title::String
  icon::String
  fields::Vector{Field}
  help::String
  fix::Any                        # changes the parameters that the fields give into the ones that the command takes
end
Spec(command, title, icon, fields, help="") = Spec(command, title, icon, fields, help, identity)
Spec(command, title, icon, fields, fix::Function) = Spec(command, title, icon, fields, "", fix)

const OPERATIONS = Pair{Any,String}["auto" => "Auto", "new" => "New Body", "join" => "Join", "cut" => "Cut", "intersect" => "Intersect"]
const SOLID_OPERATIONS = Pair{Any,String}["new" => "New Body", "join" => "Join", "cut" => "Cut", "intersect" => "Intersect"]
const EXTENTS = Pair{Any,String}["distance" => "Distance", "through_all" => "Through All"]

"Take a form's own fields out of the parameters `p`: with Through All there's no distance `far`, and Reverse Direction turns the direction round"
through!(p, far) = begin
  pop!(p, "extent", "distance") == "through_all" && (far == "distance" && (p["through_all"] = true); delete!(p, far))
  pop!(p, "reverse", false) === true && get(p, "direction", "positive") == "positive" && (p["direction"] = "negative")
  p
end
const WORLD_AXES = Pair{Any,String}["X" => "X", "Y" => "Y", "Z" => "Z"]
const WAYS = Pair{Any,String}[[1, 0, 0] => "X", [0, 1, 0] => "Y", [0, 0, 1] => "Z"]
const PLANES = Pair{Any,String}["XY" => "XY", "XZ" => "XZ", "YZ" => "YZ"]

const SPECS = Dict{String,Spec}(s.command => s for s in [
  Spec("sketch.create", "Create Sketch", "sketch", [
    Field("plane", "Plane", :plane, default="XY"),
    Field("offset", "Offset", :length, optional=true)]),
  Spec("solid.extrude", "Extrude", "extrude", [
    Field("profiles", "Profiles", :profiles),
    Field("targets", "Target Bodies", :bodies, optional=true, section=""),
    Field("direction", "Direction", :choice, default="positive", options=["positive" => "One Side", "symmetric" => "Symmetric"]),
    Field("extent", "Extent Type", :choice, default="distance", options=EXTENTS),
    Field("distance", "Distance", :length, default="10 mm"),
    Field("operation", "Operation", :choice, default="auto", options=OPERATIONS),
    Field("reverse", "Reverse Direction", :flag),
    Field("taper", "Taper Angle", :angle, optional=true)], p -> through!(p, "distance")),
  Spec("solid.revolve", "Revolve", "revolve", [
    Field("profiles", "Profile", :profiles),
    Field("axis", "Axis", :choice, default="x", options=["x" => "Sketch x", "y" => "Sketch y", "X" => "X", "Y" => "Y", "Z" => "Z"]),
    Field("direction", "Direction", :choice, default=nothing, options=[nothing => "One Side", "symmetric" => "Symmetric"]),
    Field("angle", "Angle", :angle, default="360 deg"),
    Field("operation", "Operation", :choice, default="auto", options=OPERATIONS)]),
  Spec("solid.hole", "Hole", "hole", [
    Field("position", "Face", :spot),
    Field("extent", "Extents", :choice, default="distance", options=EXTENTS),
    Field("type", "Hole Type", :choice, default="simple", options=["simple" => "Simple", "counterbore" => "Counterbore", "countersink" => "Countersink"]),
    Field("depth", "Depth", :length, default="10 mm"),
    Field("diameter", "Diameter", :length, default="5 mm"),
    Field("tip_angle", "Tip Angle", :angle, optional=true),
    Field("cb_diameter", "Counterbore Diameter", :length, optional=true),
    Field("cb_depth", "Counterbore Depth", :length, optional=true),
    Field("cs_diameter", "Countersink Diameter", :length, optional=true),
    Field("cs_angle", "Countersink Angle", :angle, optional=true)], p -> through!(p, "depth")),
  Spec("solid.fillet", "Fillet", "fillet", [
    Field("edges", "Edges", :edges),
    Field("radius", "Radius", :length, default="2 mm"),
    Field("type", "Type", :choice, default="constant", options=["constant" => "Constant radius", "curvature" => "Curvature", "chord" => "Chord width"]),
    Field("tangent_chain", "Tangent Chain", :flag, default=true)]),
  Spec("solid.chamfer", "Chamfer", "chamfer", [
    Field("edges", "Edges", :edges),
    Field("distance", "Distance", :length, default="1 mm"),
    Field("distance2", "Second Distance", :length, optional=true),
    Field("tangent_chain", "Tangent Chain", :flag, default=true)]),
  Spec("solid.shell", "Shell", "shell", [
    Field("faces", "Faces/Body", :faces),
    Field("thickness", "Thickness", :length, default="2 mm"),
    Field("direction", "Direction", :choice, default="inside", options=["inside" => "Inside", "outside" => "Outside", "both" => "Both"]),
    Field("tangent_chain", "Tangent Chain", :flag, optional=true)]),
  Spec("solid.press_pull", "Press Pull", "presspull", [
    Field("face", "Face", :face),
    Field("distance", "Distance", :length, default="2 mm")]),
  Spec("solid.box", "Box", "box", [
    Field("length", "Length", :length, default="20 mm"),
    Field("width", "Width", :length, default="20 mm"),
    Field("height", "Height", :length, default="20 mm"),
    Field("center", "Centre", :vector, default="0, 0, 10"),
    Field("operation", "Operation", :choice, default="new", options=SOLID_OPERATIONS)]),
  Spec("solid.cylinder", "Cylinder", "cylinder", [
    Field("diameter", "Diameter", :length, default="20 mm"),
    Field("height", "Height", :length, default="20 mm"),
    Field("base", "Base", :vector, default="0, 0, 0"),
    Field("axis", "Axis", :choice, default="Z", options=WORLD_AXES),
    Field("operation", "Operation", :choice, default="new", options=SOLID_OPERATIONS)]),
  Spec("solid.sphere", "Sphere", "sphere", [
    Field("diameter", "Diameter", :length, default="20 mm"),
    Field("center", "Centre", :vector, default="0, 0, 0"),
    Field("operation", "Operation", :choice, default="new", options=SOLID_OPERATIONS)]),
  Spec("solid.torus", "Torus", "torus", [
    Field("major", "Major radius", :length, default="20 mm"),
    Field("minor", "Minor radius", :length, default="5 mm"),
    Field("center", "Centre", :vector, default="0, 0, 0"),
    Field("operation", "Operation", :choice, default="new", options=SOLID_OPERATIONS)]),
  Spec("solid.cone", "Cone", "cone", [
    Field("diameter", "Base diameter", :length, default="20 mm"),
    Field("top_diameter", "Top diameter", :length, optional=true),
    Field("height", "Height", :length, default="20 mm"),
    Field("base", "Base", :vector, default="0, 0, 0"),
    Field("axis", "Axis", :choice, default="Z", options=WORLD_AXES),
    Field("operation", "Operation", :choice, default="new", options=SOLID_OPERATIONS)]),
  Spec("solid.mirror", "Mirror", "mirror", [
    Field("bodies", "Objects", :bodies),
    Field("plane", "Mirror Plane", :choice, default="YZ", options=PLANES),
    Field("combine", "Join", :flag)]),
  Spec("solid.pattern.rectangular", "Rectangular Pattern", "pattern_rect", [
    Field("bodies", "Objects", :bodies),
    Field("dir1", "Direction", :choice, default=[1, 0, 0], options=WAYS),
    Field("count1", "Quantity", :count, default="3"),
    Field("spacing1", "Spacing", :length, default="20 mm"),
    Field("dir2", "Direction 2", :choice, default=nothing, options=vcat(Pair{Any,String}[nothing => "None"], WAYS), optional=true, section=""),
    Field("count2", "Quantity 2", :count, optional=true, section=""),
    Field("spacing2", "Spacing 2", :length, optional=true, section="")]),
  Spec("solid.pattern.circular", "Circular Pattern", "pattern_circ", [
    Field("bodies", "Bodies", :bodies),
    Field("axis", "Axis", :choice, default="Z", options=WORLD_AXES),
    Field("count", "Count", :count, default="6"),
    Field("angle", "Angle", :angle, default="360 deg")]),
  Spec("solid.combine", "Combine", "combine", [
    Field("target", "Target body", :body),
    Field("tools", "Tool bodies", :bodies),
    Field("operation", "Operation", :choice, default="join", options=["join" => "Join", "cut" => "Cut", "intersect" => "Intersect"]),
    Field("keep_tools", "Keep the tools", :flag)]),
  Spec("solid.move", "Move / Copy", "move", [
    Field("bodies", "Selection", :bodies),
    Field("translate", "Distance", :vector, default="0, 0, 0"),
    Field("angle", "Angle", :angle, optional=true, section=""),
    Field("axis", "About", :choice, default=[0, 0, 1], options=WAYS),
    Field("copy", "Create Copy", :flag)]),
  Spec("solid.scale", "Scale", "scale", [
    Field("bodies", "Bodies", :bodies),
    Field("factor", "Factor", :count, default="2")]),
  Spec("solid.draft", "Draft", "draft", [
    Field("faces", "Faces", :faces),
    Field("angle", "Angle", :angle, default="3 deg"),
    Field("neutral", "Neutral plane", :choice, default="XY", options=PLANES)]),
  Spec("solid.offset_face", "Offset Face", "presspull", [
    Field("faces", "Faces", :faces),
    Field("distance", "Distance", :length, default="1 mm")]),
  Spec("face.delete", "Delete Face", "delete", [
    Field("faces", "Faces", :faces)]),
  Spec("solid.remove", "Remove", "delete", [
    Field("bodies", "Bodies", :bodies)]),
  Spec("solid.split_body", "Split Body", "split", [
    Field("body", "Body", :body),
    Field("plane", "Plane", :choice, default="XY", options=PLANES)]),
  Spec("construct.plane.offset", "Offset Plane", "plane", [
    Field("base", "From", :plane, default="XY"),
    Field("offset", "Offset", :length, default="10 mm")]),
  Spec("appearance.assign", "Appearance", "appearance", [
    Field("bodies", "Bodies", :bodies),
    Field("color", "Colour", :text, default="#4a90d9")]),
  Spec("material.assign", "Physical Material", "material", [
    Field("bodies", "Bodies", :bodies),
    Field("material", "Material", :text, default="Steel")]),
  Spec("sketch.fillet", "Sketch Fillet", "sketch_fillet", [
    Field("radius", "Radius", :length, default="2 mm")]),
  Spec("sketch.offset", "Offset", "offset", [
    Field("distance", "Distance", :length, default="2 mm"),
    Field("flip", "Other side", :flag)]),
  Spec("sketch.chamfer.equal_distance", "Sketch Chamfer", "chamfer", [
    Field("distance", "Distance", :length, default="2 mm")]),
])

"The kind of field for the parameter `name` of a command, as SolidCraft's own description `about` has it"
field_kind(name, about::AbstractDict) = begin
  name in ("edges",) && return :edges
  name in ("faces",) && return :faces
  name == "face" && return :face
  name in ("bodies", "tools", "targets", "participants") && return :bodies
  name in ("body", "target") && return :body
  get(about, "type", nothing) == "boolean" && return :flag
  haskey(about, "enum") && return :choice
  kinds = get(about, "type", nothing)
  kinds == "string" || kinds == "number" || kinds == "integer" ? :text :
  any(a -> a isa AbstractDict && get(a, "type", "") in ("number", "string"), get(about, "anyOf", Any[])) && !any(a -> a isa AbstractDict && get(a, "type", "") in ("array", "object"), get(about, "anyOf", Any[])) ? :text : :json
end

"Words for a parameter's name: `through_all` is Through all"
words(name) = (s = replace(name, '_' => ' ', '.' => ' '); isempty(s) ? s : uppercase(first(s)) * s[nextind(s, 1):end])

"""
The form of the command `c`, which is one of the commands that SolidCraft
lists. `described` is what SolidCraft says of the command's parameters
(`describe_command`), or nothing when that hasn't come yet.
"""
spec(c::AbstractDict, described=nothing) = begin
  id = String(c["id"])
  haskey(SPECS, id) && return SPECS[id]
  title, icon = String(get(c, "label", id)), String(something(get(c, "icon", nothing), "feature"))
  help = String(get(c, "params", ""))
  input = described isa AbstractDict ? get(described, "input", nothing) : nothing
  props = input isa AbstractDict ? get(input, "properties", nothing) : nothing
  if props isa AbstractDict && !isempty(props)
    needed = Set{String}(String(r) for r in get(input, "required", Any[]))
    defs = get(input, "\$defs", JSON.Object())
    fields = Field[]
    for name in sort(collect(keys(props)), by=n -> (!(n in needed), n))
      about = props[name]
      about isa AbstractDict || continue
      # A parameter that names another description has that one's kind
      ref = get(about, "\$ref", nothing)
      ref isa String && (about = get(defs, last(split(ref, '/')), about))
      kind = field_kind(name, about)
      options = Pair{Any,String}[v => words(string(v)) for v in get(about, "enum", Any[]) if v !== nothing]
      default = kind == :flag ? get(about, "default", false) === true : kind == :choice ? (isempty(options) ? "" : get(about, "default", nothing)) : ""
      push!(fields, Field(name, words(name), kind, default, options, !(name in needed)))
    end
    return Spec(id, title, icon, fields, help)
  end
  # An older command says what it takes only in words, like `face: [x,y,z]; form?: metric|acme`. Those are read too.
  Spec(id, title, icon, vcat(fields_in(help), [Field("", "Other parameters", :json, optional=true)]), help)
end

"The pieces of `text` between the characters `marks`, where those are outside every bracket"
pieces(text::AbstractString, marks) = begin
  out, depth, from = String[], 0, firstindex(text)
  for (i, c) in pairs(text)
    c in "([{" && (depth += 1)
    c in ")]}" && (depth = max(depth - 1, 0))
    depth == 0 && c in marks || continue
    push!(out, text[from:prevind(text, i)])
    from = nextind(text, i)
  end
  push!(out, text[from:end])
  String.(strip.(out))
end

const NAMED = r"^([a-z][a-z0-9_]*)(\?)?\s*(?::\s*(.*))?$"s

"""
The fields of a command from the words that SolidCraft gives for its
parameters, like `length, width, height: expr; center?: [x,y,z]; operation?`.
A name with `?` isn't needed. What isn't written that way is left out.
"""
fields_in(help::AbstractString) = begin
  fields = Field[]
  seen = Set{String}()
  # What follows an arrow is what the command gives back
  help = first(split(help, " → "))
  for part in pieces(help, ";")
    items = pieces(part, ",")
    for (i, item) in enumerate(items)
      # `radius | diameter` names two ways to give one thing, so neither is needed by itself
      ways = pieces(item, "|")
      ways = all(w -> match(NAMED, w) !== nothing, ways) ? ways : [item]
      for way in ways
        m = match(NAMED, way)
        m === nothing && continue
        name = String(m[1])
        (name in seen || length(name) > 24) && continue
        about = m[3] === nothing ? "" : String(m[3])
        # A name with nothing after it is described by the next name of its list that is
        if isempty(about)
          later = findfirst(j -> (n = match(NAMED, items[j]); n !== nothing && n[3] !== nothing), i+1:length(items))
          later === nothing || (about = String(match(NAMED, items[i+later])[3]))
        end
        options = match(r"^([A-Za-z_0-9]+(?:\|[A-Za-z_0-9]+)+)", about)
        kind = field_kind(name, Object())
        kind = kind != :json ? kind : name == "position" ? :spot : startswith(about, "bool") ? :flag : options !== nothing ? :choice :
               startswith(about, "[x,y,z]") ? :vector : :text
        choices = kind == :choice && options !== nothing ? Pair{Any,String}[o => words(String(o)) for o in split(options[1], '|')] : Pair{Any,String}[]
        kind == :choice && isempty(choices) && (kind = :text)
        needed = m[2] === nothing && length(ways) == 1
        push!(seen, name)
        push!(fields, Field(name, words(name), kind, kind == :flag ? false : kind == :choice ? (needed ? choices[1].first : nothing) : "", choices, !needed))
      end
    end
  end
  fields
end

"A number if `text` is one, else the text as it is: SolidCraft reads text as an expression like `w / 2`"
value(text::AbstractString) = (x = tryparse(Float64, strip(text)); x === nothing ? String(strip(text)) : x)

"""
The parameters of a command as SolidCraft takes them, from what a form holds.
`values` has each field's text, choice or flag by its key, and for a field
that's clicked the list of what each click sends. It gives the parameters, or
words that say what's still missing.
"""
params(s::Spec, values::AbstractDict) = begin
  out = JSON.Object()
  for f in s.fields
    v = get(values, f.key, f.default)
    if f.kind == :json
      text = strip(v isa AbstractString ? v : "")
      isempty(text) && continue
      parsed = try JSON.parse(startswith(text, "{") ? text : "{" * text * "}") catch; return "The parameters aren't JSON. Write them like \"radius\": 2" end
      parsed isa AbstractDict || return "The parameters aren't JSON."
      isempty(f.key) ? merge!(out, parsed) : (out[f.key] = parsed)
    elseif picks(f)
      list = v isa Vector ? v : v === nothing || v == "" ? Any[] : Any[v]
      if isempty(list)
        f.optional && continue
        return "Choose the $(lowercase(f.label)) in the design."
      end
      out[f.key] = many(f) ? list : list[1]
    elseif f.kind == :flag
      (v === true || !f.optional) && (out[f.key] = v === true)
    elseif f.kind == :choice
      v === nothing || v == "" || (out[f.key] = v)
    elseif f.kind == :vector
      text = strip(v isa AbstractString ? v : "")
      if isempty(text)
        f.optional && continue
        return "Type the $(lowercase(f.label)) as three numbers."
      end
      parts = split(text, ',')
      length(parts) == 3 || return "Type the $(lowercase(f.label)) as three numbers, like 0, 0, 10."
      out[f.key] = Any[value(p) for p in parts]
    else
      text = strip(v isa AbstractString ? v : "")
      if isempty(text)
        f.optional && continue
        return "Type the $(lowercase(f.label))."
      end
      out[f.key] = value(text)
    end
  end
  # A flag that asks for everything takes the place of the distance
  get(out, "through_all", false) === true && delete!(out, "distance")
  s.fix(out)
end

# --- the sketch tools ----------------------------------------------------------------

"A sketch tool that takes clicks: the command it runs, and the parameter that each click gives"
struct Tool
  command::String
  clicks::Vector{String}     # the parameter of each click. "points" alone takes clicks until Return.
  measure::String            # a parameter that the last two clicks give as the distance between them, like a radius, or ""
  fields::Vector{Field}      # what's typed beside the clicks, like how many sides
  shape::Symbol              # how it shows before the last click: :line :box :centred :circle :arc :path
end

const TOOLS = Dict{String,Tool}(t.command => t for t in [
  Tool("sketch.line", ["points"], "", Field[], :line),
  Tool("sketch.rectangle.two_point", ["p0", "p1"], "", Field[], :box),
  Tool("sketch.rectangle.center", ["center", "corner"], "", Field[], :centred),
  Tool("sketch.rectangle.three_point", ["p0", "p1", "p2"], "", Field[], :path),
  Tool("sketch.rectangle.rounded", ["p0", "p1"], "", [Field("radius", "Corner radius", :length, default="2 mm")], :box),
  Tool("sketch.circle.center", ["center", ""], "radius", Field[], :circle),
  Tool("sketch.circle.two_point", ["p0", "p1"], "", Field[], :path),
  Tool("sketch.circle.three_point", ["p0", "p1", "p2"], "", Field[], :path),
  Tool("sketch.arc.three_point", ["start", "end", "through"], "", Field[], :arc),
  Tool("sketch.arc.center_point", ["center", "start", "end"], "", Field[], :path),
  Tool("sketch.polygon.inscribed", ["center", ""], "radius", [Field("sides", "Sides", :count, default="6")], :circle),
  Tool("sketch.polygon.circumscribed", ["center", ""], "radius", [Field("sides", "Sides", :count, default="6")], :circle),
  Tool("sketch.slot.center_to_center", ["p0", "p1"], "", [Field("width", "Width", :length, default="5 mm")], :line),
  Tool("sketch.slot.overall", ["p0", "p1"], "", [Field("width", "Width", :length, default="5 mm")], :line),
  Tool("sketch.ellipse", ["center", "major", "minor"], "", Field[], :path),
  Tool("sketch.spline.fit_point", ["points"], "", Field[], :path),
  Tool("sketch.point", ["point"], "", Field[], :path),
  Tool("sketch.text", ["at"], "", [Field("text", "Text", :text, default="Text"), Field("height", "Height", :length, default="5 mm")], :path),
])

"The constraints that a button puts on what's selected in a sketch: the command, and how many things it needs"
const CONSTRAINTS = ["sketch.constraint.horizontal_vertical" => 1, "sketch.constraint.coincident" => 2, "sketch.constraint.tangent" => 2,
                     "sketch.constraint.equal" => 2, "sketch.constraint.parallel" => 2, "sketch.constraint.perpendicular" => 2,
                     "sketch.constraint.fix" => 1, "sketch.constraint.midpoint" => 2, "sketch.constraint.concentric" => 2,
                     "sketch.constraint.collinear" => 2, "sketch.constraint.symmetry" => 3]

# --- the toolbar ---------------------------------------------------------------------

"A group of the toolbar: its name, the commands that show as buttons, and the ones in its menu"
struct Group
  name::String
  main::Vector{String}
  more::Vector{String}
end

"The tabs of the toolbar, each with its groups. `:parameters` and the like are the editor's own buttons."
const TABS = [
  "Model" => [
    Group("Sketch", ["sketch.create"], String[]),
    Group("Create", ["solid.extrude", "solid.revolve", "solid.hole"],
          ["solid.box", "solid.cylinder", "solid.sphere", "solid.torus", "solid.cone", "solid.sweep", "solid.loft", "solid.pipe", "solid.thread", "solid.rib", "solid.coil", "solid.emboss"]),
    Group("Modify", ["solid.fillet", "solid.chamfer", "solid.shell", "solid.press_pull"],
          ["solid.draft", "solid.combine", "solid.scale", "solid.offset_face", "solid.split_body", "solid.split_face", "face.delete", "solid.replace_face", "solid.remove", "appearance.assign", "material.assign"]),
    Group("Arrange", ["solid.move", "solid.mirror", "solid.pattern.rectangular"], ["solid.pattern.circular", "solid.pattern.path", "solid.align"]),
    Group("Configure", ["parameters"], String[]),
    Group("Construct", ["construct.plane.offset"],
          ["construct.plane.at_angle", "construct.plane.midplane", "construct.plane.three_points", "construct.plane.tangent", "construct.axis.two_points", "construct.axis.edge", "construct.axis.through_cylinder", "construct.point.vertex", "construct.point.center"]),
  ],
  "Surface" => [
    Group("Create", ["surface.extrude", "surface.revolve", "surface.patch"], ["surface.sweep", "surface.loft", "surface.boundary", "surface.offset", "surface.ruled", "surface.blend"]),
    Group("Modify", ["surface.thicken", "surface.stitch", "surface.trim"], ["surface.extend", "surface.untrim", "surface.unstitch", "surface.reverse_normal", "surface.fillet"]),
  ],
  "Sheet Metal" => [
    Group("Create", ["sheet.flange", "sheet.hem", "sheet.convert"], ["sheet.path_flange", "sheet.perforate", "sheet.fold", "sheet.flat_pattern"]),
    Group("Modify", ["sheet.unfold", "sheet.refold"], String[]),
  ],
  "Inspect" => [
    Group("Inspect", ["inspect.measure", "inspect.section", "inspect.interference"], ["assembly.mass_properties", "inspect.center_of_mass"]),
  ],
  "Sketch" => [
    Group("Create", ["sketch.line", "sketch.rectangle.two_point", "sketch.circle.center", "sketch.arc.three_point"],
          ["sketch.rectangle.center", "sketch.rectangle.three_point", "sketch.rectangle.rounded", "sketch.circle.two_point", "sketch.circle.three_point", "sketch.arc.center_point",
           "sketch.polygon.inscribed", "sketch.polygon.circumscribed", "sketch.slot.center_to_center", "sketch.slot.overall", "sketch.ellipse", "sketch.spline.fit_point", "sketch.point", "sketch.text"]),
    Group("Modify", ["sketch.trim", "sketch.offset", "sketch.fillet"], ["sketch.chamfer.equal_distance", "sketch.extend", "sketch.construction"]),
    Group("Constrain", ["sketch.dimension", "constraints"], ["sketch.auto_constrain"]),
    Group("Reference", ["sketch.project"], String[]),
    Group("Configure", ["parameters"], String[]),
    Group("Exit", ["sketch.finish", "sketch.cancel"], String[]),
  ],
]

"""
Does the design show what the command `id` makes while its form is filled in?
It does for a command that makes or changes bodies, and for a step whose
lengths are changed.
"""
tried(id) = id == "parameters.change" || any(p -> startswith(id, p), ("solid.", "surface.", "sheet.", "face."))

"What the toolbar calls a command, where SolidCraft's own name for it is long"
const SHORT = Dict("sketch.create" => "New Sketch", "solid.pattern.rectangular" => "Pattern", "solid.move" => "Move / Copy", "construct.plane.offset" => "Plane",
  "sketch.rectangle.two_point" => "Rectangle", "sketch.circle.center" => "Circle", "sketch.arc.three_point" => "Arc", "sketch.finish" => "Finish Sketch",
  "sketch.cancel" => "Cancel", "parameters" => "Parameters", "sketch.dimension" => "Dimension", "sketch.fillet" => "Fillet", "inspect.measure" => "Measure", "inspect.section" => "Section",
  "inspect.interference" => "Interference", "sheet.convert" => "Convert", "surface.extrude" => "Extrude", "surface.revolve" => "Revolve")

"The icon of the editor's own buttons and of the commands whose SolidCraft icon the editor draws another way"
const BUTTON_ICONS = Dict("parameters" => "params", "sketch.finish" => "check-lg", "sketch.cancel" => "x-lg", "sketch.create" => "sketch",
  "sketch.rectangle.two_point" => "rect", "sketch.circle.center" => "circle", "solid.press_pull" => "presspull", "solid.pattern.rectangular" => "pattern_rect",
  "solid.pattern.circular" => "pattern_circ", "sketch.fillet" => "sketch_fillet", "sketch.arc.three_point" => "arc3")
