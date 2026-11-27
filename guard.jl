# The sandbox that the code of a page from a web server runs in, while you
# don't trust its site. See "the sandbox" in sandbox.jl.
#
#     c = Context(Site("https://example.com", folder, answer), m)
#     Guard.run(c, ex)          # run the page's code `ex` in its module m
#
# Before the code runs, Guard has Julia lower it: Julia makes the code a
# list of steps, and each step calls a function or reads a name. Guard makes
# each step that calls a function a call of `Guard.call`, which checks the
# function and its arguments first. It makes each step that reads a name a
# check of what the name holds, unless it can see now that the name is safe.
# The functions that the code defines are changed in the same way, so a call
# of one is checked too when Ladder calls it later, as it draws. The code
# still runs compiled.
#
# A call goes on as it is when it can't harm your Mac: sums, text, lists,
# units, dates, UI.jl's components. Anything else stops the code with a
# `Stopped` error, unless you said yes to it for the site:
#
#   - reading a file outside the site's own folder of the browser folder, or
#     changing any file
#   - starting a program
#   - loading a package, or running code that Guard can't check first, like
#     the code that `eval` is given
#   - calling C code
#   - using a part of Ladder, of Kip, or of Julia's own state, like ENV or
#     LOAD_PATH
#   - adding a method to a function that the page didn't make, for types
#     that the page didn't make either, which changes how the function works
#     for all of Ladder
#
# The first time, the action waits for your answer (see `waiting!`). Your
# answer for the site is kept by the action's key, so a "yes" lets the same
# kind of action go on from then on.
#
# What Guard doesn't check: the code of a package that's loaded, which runs as
# it is. That's why loading a package that isn't on this Mac needs your yes.

"Something that the code of a page wanted to do. `key` is what your answer is kept by, and `words` finish the words \"… wants to\"."
struct Action
  key::String
  words::String
end

"""
A site whose pages' code runs in the sandbox: its name, like
https://example.com, the folder of its files in the browser folder, and
`answer`, which gives what you said for an action's key: true for yes, false
for no, or nothing when you haven't said. `answer` can be called from any
thread.
"""
struct Site
  name::String
  folder::String
  answer::Any
end

"""
The code of a page of `site`, which runs in the module `m`. `also` are other
modules of the page, whose functions and types count as the page's own.
"""
struct Context
  site::Site
  m::Module
  also::Vector{Module}
end
Context(site::Site, m::Module) = Context(site, m, Module[])

"The error of code that the sandbox stopped. `asked` is true when Ladder will ask you about it."
struct Stopped <: Exception
  site::String
  action::Action
end
Base.showerror(io::IO, e::Stopped) = print(io, "The sandbox stopped this code: it wants to ", e.action.words, ".")

# --- what waits for your answer ---

const WAITING = Tuple{String,Action}[]
const WAITING_LOCK = ReentrantLock()

"Take each action that waits for your answer, with the name of its site"
waiting!() = lock(WAITING_LOCK) do
  w = copy(WAITING)
  empty!(WAITING)
  w
end

"""
What `answer`, the answer of a site, says of the action `a` as the code is
about to do it: true, false, or nothing when you haven't said. A site's
answer is asked by the action's key. The answer of an agent's code has a
method of its own, which asks you there and then, and waits: see repl.jl.
"""
answer_now(answer, a::Action) = answer(a.key)

"""
Go on when you said yes to `a` for the site of `c`, or else stop the code.
When you haven't said, `a` waits for your answer.
"""
@noinline permit(c::Context, a::Action) = begin
  said = answer_now(c.site.answer, a)
  said === true && return nothing
  said === nothing && lock(WAITING_LOCK) do
    any(w -> w[1] == c.site.name && w[2].key == a.key, WAITING) || push!(WAITING, (c.site.name, a))
  end
  throw(Stopped(c.site.name, a))
end

# --- what's open to a page's code ---

"The parts of Base whose functions a page may call"
const OPEN_BASE_PARTS = (:Math, :Iterators, :Broadcast, :Order, :Sort, :Checked, :MathConstants, :Unicode, :Rounding,
                         :FastMath, :MPFR, :GMP, :Ryu, :IteratorsMD, :Cartesian, :SimdLoop, :Threads, :GC, :Meta,
                         :Enums, :ScopedValues, :CoreLogging, :Multimedia, :MultiplicativeInverses, :Sys)

"The functions of Base.Docs that a docstring calls. The others can give any name of any module, like Docs.resolve."
const DOCS_OPEN = (:doc!, :docstr, :Binding, :DocStr, :MultiDoc, :aliasof, :signature, :doc, :catdoc, :parsedoc)

"The packages of Julia itself whose functions a page may call"
const OPEN_STDLIBS = (:LinearAlgebra, :Statistics, :Dates, :Printf, :Random, :SparseArrays, :Unicode, :Base64, :SHA,
                      :UUIDs, :Logging)

"The parts of those that reach outside: BLAS and LAPACK can load a library of C code"
const SHUT_STDLIB_PARTS = (:BLAS, :LAPACK)

"The parts of Base whose functions a page may call only when Base makes them public: the rest work with C memory"
const PUBLIC_BASE_PARTS = (:GMP, :MPFR)

"The registered packages whose functions a page may call: they work things out and change nothing outside"
const OPEN_PACKAGES = (:Colors, :ColorTypes, :FixedPointNumbers, :StaticArrays, :GeometryBasics, :OrderedCollections,
                       :DataStructures, :MacroTools)

"The folders of the repositories, of Kip's packages, whose code a page may call"
const OPEN_REPOS = ("UI.jl", "Units.jl", "Prospects.jl", "Font.jl", "Sequences.jl", "Destructure.jl", "DynamicVar.jl",
                    "MiniFB.jl", "URI.jl")

"The parts of those repositories that reach outside the page: native code, windows, the microphone, saving files"
const SHUT_PARTS = ("UI.jl/Interface/objc", "UI.jl/Interface/window", "UI.jl/Interface/media", "UI.jl/Interface/save",
                    "UI.jl/Interface/inspector", "UI.jl/Interface/testing", "UI.jl/Interface/Specific",
                    "UI.jl/Interface/Semantic/Recorder")

"Other modules that a page may use, like the units of a sheet. Ladder adds them."
const OPEN_MODULES = Ref(Base.IdSet{Module}())

"Let the code of pages use the module `m`"
open!(m::Module) = (s = copy(OPEN_MODULES[]); push!(s, m); OPEN_MODULES[] = s; nothing)

"""
A table that's read with no lock and changed by copying it: `get` reads the
table that's there now, and `put!` puts a new one in its place.
"""
struct Kept{K,V}
  table::Ref{IdDict{K,V}}
  lock::ReentrantLock
end
Kept{K,V}() where {K,V} = Kept{K,V}(Ref(IdDict{K,V}()), ReentrantLock())
Base.get(k::Kept, key, default) = get(k.table[], key, default)
put(k::Kept, key, value) = lock(k.lock) do
  t = copy(k.table[])
  t[key] = value
  k.table[] = t
  value
end

const MODULE_OPEN = Kept{Module,Bool}()

"The file that each module of Kip's was made from, as Kip has it now"
const KIP_FILES = Ref((0, IdDict{Module,String}()))

kip_file(m::Module) = begin
  isdefined(@__MODULE__, :Kip) || return ""
  mods = Kip.modules
  n, files = KIP_FILES[]
  if n != length(mods)
    files = IdDict{Module,String}(v => k for (k, v) in mods)
    KIP_FILES[] = (length(mods), files)
  end
  get(files, m, "")
end

"The files of the methods of the functions of the module `m`'s own"
method_files(m::Module) = begin
  files = Set{String}()
  for n in names(m, all=true)
    Base.invokelatest(isdefined, m, n) || continue
    v = Base.invokelatest(getglobal, m, n)
    # Kip writes an `eval` and an `include` in each module that it makes, which the sandbox never lets code call
    v isa Function && parentmodule(v) === m && !(n in (:eval, :include)) || continue
    for meth in methods(v)
      meth.module === m && push!(files, string(meth.file))
    end
  end
  files
end

"The modules from `m` up to the first that has no parent but Main, or itself"
module_chain(m::Module) = begin
  chain = Module[m]
  while (p = parentmodule(chain[end])) !== chain[end] && p !== Main
    push!(chain, p)
  end
  chain
end

"True when a page's code may use the module `m`: a part of Julia, or a package that changes nothing outside the page"
open_module(m::Module) = begin
  known = get(MODULE_OPEN, m, nothing)
  known === nothing || return known
  put(MODULE_OPEN, m, find_open(m))
end

find_open(m::Module) = begin
  (m === Base || m === Core) && return true
  m in OPEN_MODULES[] && return true
  chain = module_chain(m)
  any(x -> x in OPEN_MODULES[], chain) && return true
  top = chain[end]
  i = findfirst(==(Base), chain)
  i === nothing || return i > 1 && (nameof(chain[i-1]) in OPEN_BASE_PARTS || nameof(chain[i-1]) in PUBLIC_BASE_PARTS)
  top === Core && return false   # Core.Compiler and Core.Intrinsics
  # A package of Julia's, or a registered one: a page's code can't make a module with a UUID
  any(x -> nameof(x) in SHUT_STDLIB_PARTS, chain) && return false
  (nameof(top) in OPEN_STDLIBS || nameof(top) in OPEN_PACKAGES) && return Base.PkgId(top).uuid !== nothing
  for x in chain
    file = kip_file(x)
    if isempty(file)
      # A built app can load a module of Kip's without Kip's table. Then the files of its methods say where it's
      # from: each must be a file of a repository that's open, since a macro of one can write methods anywhere.
      files = method_files(x)
      isempty(files) && continue
      return all(open_file, files)
    end
    return open_file(file)
  end
  false
end

"True when the file at `file` is one of a repository whose code a page may call"
open_file(file::AbstractString) = any(r -> occursin("/$r/", file), OPEN_REPOS) && !any(p -> occursin(p, file), SHUT_PARTS)

"The module that made `x`, a function, a type, or a thing that can be called"
maker(x) = begin
  if x isa Type
    T = Base.unwrap_unionall(x)
    return T isa DataType ? T.name.module : Core
  end
  typeof(x).name.module
end

"True when the page's code made `x`: a function, a type, or a module"
owned(c::Context, m::Module) = m === c.m || m in c.also
owned(c::Context, x) = owned(c, maker(x))

"""
How the sandbox takes a call of `f`, which the page's code didn't make:

  - `:free` runs as it is. A function or a type that it's given must be free too.
  - `:get` reads a field or a name: what it gives is checked.
  - `:set` changes a field: the thing mustn't be Ladder's.
  - `:globals` changes a module, and `:types` a type: it must be the page's own.
  - `:place` reads or changes a file, or starts a program: see `place_action`.
  - `:load` loads a package or a module's names.
  - `:forward` calls another function, which is checked.
  - `:shut` needs your yes.
"""
calling(@nospecialize(f)) = begin
  known = get(CALLING, f, nothing)
  known === nothing || return known
  put(CALLING, f, find_calling(f))
end

const CALLING = Kept{Any,Symbol}()

"The functions that call another, with the arguments that they're given"
const FORWARDERS = (Core.kwcall, Core._apply_iterate, Base.invokelatest, Core._call_latest, Core.invoke,
                    Base.invoke_in_world, Core._call_in_world, Core._call_in_world_total)
const GETTERS = (Core.getfield, Base.getproperty, Core.getglobal)
const SETTERS = (Core.setfield!, Base.setproperty!, Core.swapfield!, Core.modifyfield!, Core.replacefield!,
                 Core.setfieldonce!, Base.swapproperty!, Base.modifyproperty!, Base.replaceproperty!, Base.setpropertyonce!)
"The functions that change a module, with the place of the module among their arguments"
const MODULE_CHANGERS = Dict{Any,Int}(Core.setglobal! => 1, Core.swapglobal! => 1, Core.modifyglobal! => 1,
                                      Core.replaceglobal! => 1, Core.setglobalonce! => 1, Core.declare_global => 1,
                                      Core.declare_const => 1, Core._structtype => 1, Core._abstracttype => 1,
                                      Core._primitivetype => 1)
"The functions that change a type as it's made, with the place of the type among their arguments"
const TYPE_CHANGERS = Dict{Any,Int}(Core._setsuper! => 1, Core._typebody! => 2, Core._defaultctors => 1)
const LOADERS = (Base._eval_import, Base._eval_using)

"The names of the functions of Base and of Base.Filesystem that read a file, or start a program when they're given one"
const READS = (:read, :read!, :readbytes!, :readline, :readlines, :eachline, :readchomp, :readuntil, :readeach,
               :countlines, :isfile, :isdir, :ispath, :islink, :issocket, :isfifo, :ischardev, :isblockdev, :ismount,
               :isreadable, :iswritable, :isexecutable, :filesize, :mtime, :ctime, :filemode, :stat, :lstat, :readdir,
               :walkdir, :realpath, :readlink, :samefile, :uperm, :gperm, :operm, :diskstat, :open, :run, :success)
"The names of the functions that change a file or a folder, and what each does, to finish \"… wants to\""
const CHANGES = Dict(:write => "write to", :rm => "delete", :unlink => "delete", :mkdir => "make the folder",
                     :mkpath => "make the folder", :touch => "change", :chmod => "change who can use",
                     :chown => "change who owns", :symlink => "make a link at", :hardlink => "make a link at",
                     :rename => "move a file to", :cp => "copy a file to", :mv => "move a file to",
                     :cptree => "copy files to", :sendfile => "copy a file to", :truncate => "change",
                     :mktemp => "make a file in", :mktempdir => "make a folder in")
"The functions of Base.Filesystem that only work out a path, and read no file"
const PATH_ONLY = (:joinpath, :splitext, :basename, :dirname, :splitdir, :splitpath, :splitdrive, :abspath, :normpath,
                   :isabspath, :isdirpath, :relpath, :expanduser, :contractuser, :homedir, :pwd, :tempdir, :tempname,
                   :path_separator)
"The functions of Base.Libc that a page may call"
const LIBC_OPEN = (:time, :strftime, :strptime, :TmStruct, :getpid, :rand, :srand)

"Functions of Base that a page's code may not call, though Base makes them public"
const BASE_SHUT = (:include_string, :evalfile, :require, :download, :exit, :atexit, :redirect_stdout, :redirect_stderr,
                   :task_local_storage, :pushdisplay, :popdisplay, :disable_logging, :global_logger, :current_task,
                   :withenv, :fdio, :pointer, :macroexpand, :macroexpand!, Symbol("@macroexpand"), Symbol("@macroexpand1"),
                   Symbol("@static"), :lower, :lower!, :dotgetproperty, :set_process_title, :which, :enable, :load_path,
                   :active_project, :current_project, :find_package, :pathof, :pkgdir, :functionloc, :parse_file,
                   :lbt_forward, :lbt_set_forward, :lbt_get_forward,
                   :redirect_stdin, :redirect_stdio, :kill, :pointer_from_objref, :code_lowered, :code_typed,
                   :delete_method, :reinit_stdio, :set_active_project, :compilecache, :include_dependency,
                   :disable_sigint, :reenable_sigint, :sigatomic_begin, :sigatomic_end, :_exit, :ccall_macro_lower)
"The intrinsics that reach memory or C code"
const SHUT_INTRINSICS = (:pointerref, :pointerset, :cglobal, :llvmcall, :atomic_pointerref, :atomic_pointerset,
                         :atomic_pointerswap, :atomic_pointermodify, :atomic_pointerreplace, :atomic_fence)

"Types of Base that a page's code may not make: they reach your environment, a file or a stream of the Mac"
const BASE_SHUT_TYPES = (:EnvDict, :IOStream, :TTY, :PipeEndpoint, :Process, :LibuvStream, :LibuvServer, :PipeServer,
                         :BufferStream, :AsyncCondition, :ProcessChain)

"Functions of Core that a page's code may not call"
const CORE_SHUT = (:memoryrefnew, :memoryrefset!, :memoryrefget, :memoryrefswap!, :memoryrefmodify!,
                   :memoryrefreplace!, :memoryrefsetonce!, :memoryref_isassigned, :memoryrefoffset,
                   :_eval_import, :_eval_using, :_import, :_using, :OpaqueClosure, :CodeInfo, :MethodInstance,
                   :CodeInstance, :Method, :TypeMapEntry, :MethodTable)
"Functions of Base that aren't public, which Julia's lowering or its usual macros call"
const BASE_HELPERS = (:indexed_iterate, :broadcasted, :materialize, :materialize!, :dotgetproperty, :literal_pow, :vect,
                      :Generator, :cmd_gen, :typed_vcat, :typed_hcat, :typed_hvcat, :typed_hvncat, :hvncat, :kwerr,
                      :structdiff, :inferencebarrier, :tail, :front, :depwarn, :sync_end, :sync_varname, :_wait2,
                      :string, :repr, :merge, :pairs, :Pairs, :KeySet, :ValueIterator, :Fix1, :Fix2, :Fix, :splat,
                      :afoldl, :to_index, :to_indices, :oneto, :OneTo, :setindex, :haskey, :_stable_typeof,
                      :invokelatest, :printstyled, :time_ns, :gc_num, :GC_Diff, :time_print, :cumulative_compile_time_ns,
                      :cumulative_compile_timing, :gc_alloc_count, :elapsedtime, :timev_print, :_add_ptr_names!,
                      :isexpr, :remove_linenums!)

"""
The files of Base whose functions only work things out: numbers, text, lists,
tables, printing. A function of Base that isn't public, like one that Julia's
lowering calls for a call with keywords, is free when all of its methods are
in these files.
"""
const BASE_SAFE_FILES = Set(["abstractarray.jl", "abstractarraymath.jl", "abstractdict.jl", "abstractset.jl",
  "accumulate.jl", "anyall.jl", "array.jl", "arraymath.jl", "arrayshow.jl", "asyncmap.jl", "baseext.jl", "bitarray.jl",
  "bitset.jl", "bool.jl", "channels.jl", "char.jl", "combinatorics.jl", "complex.jl", "condition.jl", "coreio.jl",
  "deepcopy.jl", "dict.jl", "div.jl", "error.jl", "errorshow.jl", "essentials.jl", "expr.jl", "float.jl",
  "floatfuncs.jl", "generator.jl", "hashing.jl", "iddict.jl", "idset.jl", "indices.jl", "int.jl", "intfuncs.jl",
  "io.jl", "iobuffer.jl", "irrationals.jl", "linked_list.jl", "lock.jl", "methodshow.jl", "missing.jl",
  "multidimensional.jl", "namedtuple.jl", "ntuple.jl", "number.jl", "operators.jl", "pair.jl", "parse.jl",
  "promotion.jl", "range.jl", "rational.jl", "reduce.jl", "reducedim.jl", "refvalue.jl", "regex.jl",
  "reinterpretarray.jl", "reshapedarray.jl", "rounding.jl", "set.jl", "show.jl", "slicearray.jl", "some.jl",
  "strings/annotated.jl", "strings/annotated_io.jl", "strings/basic.jl", "strings/io.jl", "strings/lazy.jl",
  "strings/search.jl", "strings/string.jl", "strings/substring.jl", "strings/util.jl", "subarray.jl",
  "summarysize.jl", "task.jl", "threads_overloads.jl", "timing.jl", "tuple.jl", "twiceprecision.jl", "uuid.jl",
  "version.jl", "views.jl", "weakkeydict.jl"])

"The file of Base that the method `m` is in, like strings/basic.jl"
base_file(m::Method) = begin
  s = replace(string(m.file), r"^\./" => "")
  i = findlast("/base/", s)
  i === nothing ? s : s[last(i)+1:end]
end

"True when each method of Base's own of the function `f` is in a file of `BASE_SAFE_FILES`"
base_safe(f) = begin
  ms = [m for m in methods(f) if m.module === Base]
  !isempty(ms) && all(m -> base_file(m) in BASE_SAFE_FILES, ms)
end

find_calling(@nospecialize(f)) = begin
  f isa Type && return calling_type(f)
  # An intrinsic is Core's by its type. Most work out numbers, as `@simd` and `@enum` use them, but some reach memory and C code.
  f isa Core.IntrinsicFunction && return nameof(f) in SHUT_INTRINSICS ? :shut : :free
  any(x -> x === f, FORWARDERS) && return :forward
  any(x -> x === f, GETTERS) && return :get
  any(x -> x === f, SETTERS) && return :set
  any(x -> x === f, LOADERS) && return :load
  haskey(MODULE_CHANGERS, f) && return :globals
  haskey(TYPE_CHANGERS, f) && return :types
  m = maker(f)
  n = f isa Function ? nameof(f) : nameof(typeof(f))
  n in (:eval, :include) && return :shut
  isdefined(@__MODULE__, :Kip) && m === Kip && return n === :require ? :load : :shut
  s = string(n)
  (startswith(s, "unsafe_") || startswith(s, "_unsafe")) && return :shut
  if m === Base || m === Base.Filesystem
    (n in READS || haskey(CHANGES, n)) && return :place
    m === Base.Filesystem && return n in PATH_ONLY ? :free : :shut
    n in BASE_SHUT && return :shut
    return Base.ispublic(Base, n) || n in BASE_HELPERS && n !== :dotgetproperty || base_safe(f) ? :free : :shut
  end
  # The names that are shut in Base are shut in each part of Julia's own too, and in the packages that a page may use
  (n in BASE_SHUT || startswith(s, "lbt_")) && return :shut
  any(x -> nameof(x) in PUBLIC_BASE_PARTS, module_chain(m)) && in_julia(m) && return Base.ispublic(m, n) ? :free : :shut
  m === Base.Libc && return n in LIBC_OPEN ? :free : :shut
  m === Base.Docs && return n in DOCS_OPEN || startswith(s, "@") ? :free : :shut
  m === Core && return n in CORE_SHUT ? :shut : :free
  open_module(m) ? :free : :shut
end

calling_type(T::Type) = begin
  U = Base.unwrap_unionall(T)
  # A Union makes a thing of one of its types
  U isa Union && return calling_type(U.a) === :free && calling_type(U.b) === :free ? :free : :shut
  U isa DataType || return :free
  U <: Ptr && return :shut
  m = U.name.module
  m === Core && return nameof(U) in CORE_SHUT ? :shut : :free
  m === Base && return nameof(U) in BASE_SHUT_TYPES ? :shut : :free
  m === Base.Docs && return nameof(U) in DOCS_OPEN ? :free : :shut
  m === Base.Libc || m === Base.Filesystem ? :shut : open_module(m) ? :free : :shut
end

# --- the words of an action ---

"A path as you would say it: notes.txt in Downloads, Documents in your home folder"
place_words(path::AbstractString) = begin
  p = rstrip(path, '/')
  name, parent = basename(p), dirname(p)
  parent == homedir() ? "$name in your home folder" : isempty(basename(parent)) ? name : "$name in $(basename(parent))"
end

"The folder of `path`, with ~ for your home folder, which the answer for an action on the file is kept by"
folder_key(path::AbstractString) = Base.Filesystem.contractuser(dirname(rstrip(path, '/')))

"The full name of the function or type `f`, like Base.Filesystem.rm"
full_name(f) = f isa Module ? join(fullname(f), '.') : begin
  m = maker(f)
  n = f isa Type ? nameof(Base.unwrap_unionall(f) isa DataType ? Base.unwrap_unionall(f) : f) :
      f isa Function ? nameof(f) : nameof(typeof(f))
  "$(join(fullname(m), '.')).$n"
end

"Ladder's own module. Ladder puts itself here."
const LADDER = Ref{Module}(Main)

"Whose the module `m` is, in words: Ladder's, Kip's, Julia's or a package's"
whose(m::Module) = begin
  chain = module_chain(m)
  top = chain[end]
  isdefined(@__MODULE__, :Kip) && top === Kip ? "Kip, which loads code" :
  top === Main || LADDER[] in chain ? "Ladder itself" :
  in_julia(m) ? "Julia" :
  "the package $(nameof(top))"
end

"The action of calling `f`, which is shut. `alias` is a name that it has, for a function that has none of its own."
shut_action(f, alias::Symbol=:_) = begin
  n = full_name(f)
  m = maker(f)
  if alias !== :_ && startswith(string(f isa Function ? nameof(f) : :_), "#")
    return Action("call $alias of $(join(fullname(m), '.'))", "use $alias, a part of $(whose(m))")
  end
  words = m === Base.Filesystem ? "use $(nameof(f)), which works with the files of your Mac" :
          m === Base.Libc ? "use $(nameof(f)), which calls C code" :
          nameof(f) in (:eval, :include, :include_string, :evalfile) ? "run code that the sandbox can't check first" :
          m === Base || m === Core || open_module(m) ? "use $n, which can reach outside the page" :
          "use $n, a part of $(whose(m))"
  Action("call $n", words)
end

"The action of reaching into the module `m`, which is shut"
module_action(m::Module) = Action("module $(join(fullname(m), '.'))", "reach into $(join(fullname(m), '.')), a part of $(whose(m))")

const ENV_ACTION = Action("ENV", "read and change your environment variables, which can hold passwords")

# --- the checks of a call ---

"""
Call `f` with `args`, for the code of a page of `c`, if the sandbox lets it.
The code that `guard!` changed calls this for each of its own calls.
"""
call(c::Context, f::F, args::Vararg{Any,N}) where {F,N} = begin
  k = checked(c, f, args)
  r = f(args...)
  k === :get && got!(c, r, f, args, true)
  k === :globals && any(x -> x === f, TYPE_MAKERS) && made!(r)
  r
end

"The functions that make a type, which the code of a struct, an abstract type or a closure calls"
const TYPE_MAKERS = (Core._structtype, Core._abstracttype, Core._primitivetype)

"""
The types that the code of pages made, in their own modules. Julia builds a
type in steps, and a type that isn't finished can't be looked into, so the
steps after the first know it by this.
"""
const MADE = Base.IdSet{Any}()
const MADE_LOCK = ReentrantLock()
made!(@nospecialize(t)) = (lock(() -> push!(MADE, t), MADE_LOCK); nothing)
made(@nospecialize(t)) = lock(() -> t in MADE, MADE_LOCK)

# The checks below are compiled once, for any function and arguments, and the
# fast ones above call them only when they must. Code with many calls would
# otherwise take Julia far longer to compile than it takes to run.
@noinline slow_call(c::Context, @nospecialize(f), @nospecialize(args::Tuple)) = call(c, f, args...)
@noinline slow_call_to_call(c::Context, @nospecialize(f), @nospecialize(args::Tuple)) = call_to_call(c, f, args...)

"""
Call `f` with `args`, for code of a page of `c`, where the sandbox knew `f`
as it changed the code and found it free: only the arguments are checked.
`known` is the function that it knew. A name can mean another function in a
later world, and then the call is checked as any other is.
"""
@inline free_call(c::Context, known, f::F, args::Vararg{Any,N}) where {F,N} = begin
  f === known || return slow_call(c, f, args)
  passes(c, args)
  f(args...)
end

"""
Read a field or a name with `f`, a function like `getfield` that the sandbox
knew as it changed the code, for code of a page of `c`. What it gives is
checked only when it can be a function, a type or a module, so reading a
field of a number or a list costs nothing. `strict` is false when the code
only calls what it gives.
"""
@inline got_call(c::Context, strict::Bool, known, f::F, args::Vararg{Any,N}) where {F,N} = begin
  f === known || return strict ? slow_call(c, f, args) : slow_call_to_call(c, f, args)
  a = args[1]
  a isa Module && module_check(c, a)
  r = f(args...)
  (a isa Module || r isa Function || r isa Type || r isa Module || r isa Base.EnvDict) && got!(c, r, f, args, strict)
  r
end

"Stop the code when it reads a name of the module `m`, which it may not"
@noinline module_check(c::Context, m::Module) = (module_ok(c, m) || permit(c, module_action(m)); nothing)

"Stop the code when one of `args` is a function that the page may not hand to code that the sandbox doesn't step through"
@inline passes(c::Context, args::Tuple) = (foreach(a -> passed(c, a), args); nothing)
@inline passed(c::Context, a) = nothing
@noinline passed(c::Context, a::Ptr) = permit(c, Action("pointer", "use a pointer to memory, which can reach anything in Ladder"))
@noinline passed(c::Context, a::Base.EnvDict) = permit(c, ENV_ACTION)
@inline passed(c::Context, a::Function) = owned(c, a) && !(nameof(a) in (:eval, :include)) ? nothing : passed_slow(c, a)
@noinline passed_slow(c::Context, @nospecialize(a)) = begin
  calling(a) === :free || permit(c, Action("pass $(full_name(a))", "pass $(full_name(a)) to code that the sandbox can't check"))
  nothing
end

"""
Call `f` with `args`, as `call` does, for a step whose value the code only
calls. A function that reads a file or starts a program can be its value then,
since its call is checked.
"""
call_to_call(c::Context, f::F, args::Vararg{Any,N}) where {F,N} = begin
  k = checked(c, f, args)
  r = f(args...)
  k === :get && got!(c, r, f, args, false)
  r
end

"Check the call of `f` with `args`, and give how it's taken: see `calling`"
@noinline checked(c::Context, @nospecialize(f), @nospecialize(args::Tuple)) = begin
  k = owned(c, f) ? (nameof(f isa Function ? f : typeof(f)) in (:eval, :include) ? :shut : :free) : calling(f)
  if k === :free
    functions!(c, args)
  elseif k === :forward
    # A splat iterates with the function that it's given, which must be free too
    f === Core._apply_iterate && !isempty(args) && functions!(c, (args[1],))
    g, rest = forwarded(f, args)
    return checked(c, g, rest)
  elseif k === :get
    !isempty(args) && args[1] isa Module && !module_ok(c, args[1]) && permit(c, module_action(args[1]))
  elseif k === :set
    if !isempty(args)
      x = args[1]
      if x isa Module
        owned(c, x) || permit(c, Action("change $(join(fullname(x), '.'))", "change $(join(fullname(x), '.')), a part of $(whose(x))"))
      else
        # A thing of Julia's own, like a task or a stream, has fields that Julia counts on, so only the page's own things
        # and those of a package that a page may use can change
        T = typeof(x)
        # Threads.@spawn says which threads may run the task that it makes
        sticky = x isa Task && length(args) >= 2 && args[2] === :sticky
        sticky || owned(c, T) || made(T) || !in_julia(maker(x)) && open_module(maker(x)) ||
          permit(c, Action("change $(full_name(T))", "change a $(nameof(T)), a part of $(whose(maker(x)))"))
      end
    end
    length(args) >= 3 && value!(c, nothing, :_, args[3], true)
    functions!(c, args)
  elseif k === :globals
    i = MODULE_CHANGERS[f]
    length(args) >= i && args[i] isa Module && !owned(c, args[i]) &&
      permit(c, Action("change $(join(fullname(args[i]), '.'))", "change $(join(fullname(args[i]), '.')), a part of $(whose(args[i]))"))
    # A name of the page's can't be given a value that the page may not hold, like ENV, even by code that the sandbox didn't step through
    f in (Core.setglobal!, Core.declare_const, Core.swapglobal!, Core.setglobalonce!) && length(args) >= 3 &&
      value!(c, nothing, :_, args[3], true)
  elseif k === :types
    i = TYPE_CHANGERS[f]
    length(args) >= i && args[i] isa Type && !made(args[i]) &&
      permit(c, Action("change $(full_name(args[i]))", "change how $(full_name(args[i])) is made"))
  elseif k === :place
    a = place_action(c, f, args)
    a === nothing || permit(c, a)
    functions!(c, args)
  elseif k === :load
    a = load_action(c, f, args)
    a === nothing || permit(c, a)
  else
    permit(c, shut_action(f))
  end
  k
end

"The function that a forwarding call like `invokelatest(g, xs...)` calls, and its arguments"
forwarded(@nospecialize(f), @nospecialize(args::Tuple)) = begin
  if f === Core.kwcall
    # The keywords stay first, for `place_action`. A call with keywords of a function that forwards, like
    # `invokelatest(open, path; write=true)`, gives its keywords to the function that it forwards to.
    g, rest = args[2], args[3:end]
    while any(x -> x === g, FORWARDERS) && g !== Core.kwcall
      g, rest = forwarded(g, rest)
    end
    return (g, (args[1], rest...))
  end
  f === Core._apply_iterate && return (args[2], spread(args[3:end]))
  f === Core.invoke && return (args[1], args[3:end])
  f === Base.invoke_in_world || f === Core._call_in_world || f === Core._call_in_world_total ? (args[2], args[3:end]) : (args[1], args[2:end])
end

"The arguments that `f(xs...)` gives: the items of each of `xs` that's a tuple or an array. Ladder doesn't step through anything else, which can't hold a function that the code can't have."
spread(xs::Tuple) = Tuple(Iterators.flatten(x isa Union{Tuple,AbstractArray,NamedTuple} ? x : () for x in xs))

"Stop the code when one of `args` is a function or a type that the page may not call, or a pointer, or ENV"
functions!(c::Context, @nospecialize(args::Tuple)) = begin
  for a in args
    a isa NamedTuple && (functions!(c, Tuple(a)); continue)
    a isa Ptr && permit(c, Action("pointer", "use a pointer to memory, which can reach anything in Ladder"))
    a isa Base.EnvDict && permit(c, ENV_ACTION)
    (a isa Function || a isa Type) || continue
    owned(c, a) && !(a isa Function && nameof(a) in (:eval, :include)) && continue
    calling(a) === :free || permit(c, Action("pass $(full_name(a))", "pass $(full_name(a)) to code that the sandbox can't check"))
  end
end

"Check what a call that reads a field or a name gave: a function, a type or a module that the page may not use stops the code"
@noinline got!(c::Context, @nospecialize(v), @nospecialize(f), @nospecialize(args), strict::Bool) = begin
  while any(x -> x === f, FORWARDERS)
    f, args = forwarded(f, args)
    !isempty(args) && args[1] isa NamedTuple && (args = args[2:end])
  end
  length(args) >= 2 && args[1] isa Module && args[2] isa Symbol ? value!(c, args[1], args[2], v, strict) : value!(c, nothing, :_, v, strict)
end

"""
True when the page's code may hold `v`, which the name `name` of the module
`mod` holds, or which a field held when `mod` is nothing. A function, a type
or a module that the page may not use isn't, and nor are ENV, LOAD_PATH and
the like. With `strict`, the code may hold only a function that's free: it
could hand the function to code that the sandbox doesn't step through, which
would call it unchecked. Without, the code only calls it, so the call is checked.
"""
holds(c::Context, @nospecialize(mod), name::Symbol, @nospecialize(v), strict::Bool=true) = begin
  if v isa Module
    return module_ok(c, v)
  elseif v isa Function || v isa Type
    owned(c, v) && return !(v isa Function && nameof(v) in (:eval, :include))
    return strict ? calling(v) === :free : calling(v) !== :shut
  elseif v isa Base.EnvDict
    return false
  elseif v isa Ptr
    return false
  elseif mod isa Module && ismutable(v)
    # A list or a table of Julia's own state, like LOAD_PATH, or of Ladder's or of a package's that's shut
    home = Base.binding_module(mod, name)
    owned(c, home) && return true
    in_julia(home) && return name in (:stdout, :stderr, :stdin)
    return open_module(home)
  elseif mod isa Module
    # A thing of Ladder's own, which a name of the page can hold as Ladder gave it the name
    m = maker(v)
    return owned(c, m) || made(typeof(v)) || in_julia(m) || open_module(m)
  end
  true
end

"True when the page's code may hold the module `m`, and read its names: each function of a part of Julia's own is checked as it's called"
module_ok(c::Context, m::Module) = owned(c, m) || open_module(m) || in_julia(m) && !(module_chain(m)[end] === Core && m !== Core)

"True when the module `m` is Julia's own: Base or Core, or a part of one"
in_julia(m::Module) = (top = module_chain(m)[end]; top === Base || top === Core)

"Go on when the page's code may hold `v`: see `holds`"
@noinline value!(c::Context, @nospecialize(mod), name::Symbol, @nospecialize(v), strict::Bool=true) = begin
  holds(c, mod, name, v, strict) && return nothing
  v isa Base.EnvDict && return permit(c, ENV_ACTION)
  v isa Ptr && return permit(c, Action("pointer", "use a pointer to memory, which can reach anything in Ladder"))
  v isa Module && return permit(c, module_action(v))
  (v isa Function || v isa Type) && calling(v) !== :shut &&
    return permit(c, Action("pass $(full_name(v))", "pass $(full_name(v)) to code that the sandbox can't check"))
  (v isa Function || v isa Type) && return permit(c, shut_action(v, name))
  m = Base.binding_module(mod, name)
  permit(c, Action("use $(join(fullname(m), '.')).$name", "use $name, a part of $(m === Base || m === Core ? "Julia's own state" : whose(m))"))
end

"Read the name `name` of the module `mod` for the code of a page of `c`, if the sandbox lets it"
look(c::Context, mod::Module, name::Symbol) = begin
  v = getglobal(mod, name)
  value!(c, mod, name, v, true)
  v
end

"Read the name `name`, as `look` does, for a step whose value the code only calls"
look_to_call(c::Context, mod::Module, name::Symbol) = begin
  v = getglobal(mod, name)
  value!(c, mod, name, v, false)
  v
end

# --- reading and changing files, starting programs ---

"The full path of `p`, a path or a thing like one, with ~ for your home folder and no links"
full_path(p) = begin
  path = normpath(abspath(expanduser(string(p))))
  ispath(path) ? (try realpath(path) catch; path end) : path
end

"True when `path` is in the folder `folder`, or is it"
inside(path::AbstractString, folder::AbstractString) = !isempty(folder) && (path == folder || startswith(path, rstrip(folder, '/') * "/"))


"True when the call `open(args...)`, with the keywords `kw`, writes to its file. Flags given as a number, as Base.Filesystem.open takes them, count as writing."
opens_to_write(args::Tuple, kw) = begin
  mode = findfirst(a -> a isa AbstractString, args[2:end])
  m = mode === nothing ? "" : args[mode+1]
  occursin('w', m) || occursin('a', m) || occursin('+', m) || any(a -> a isa Integer, args[2:end]) ||
    (kw !== nothing && any(k -> get(kw, k, false) === true, (:write, :append, :truncate, :create)))
end

"The programs that the command `cmd` starts, and whether it sends what they say to a file"
programs(cmd::Cmd) = ([basename(first(cmd.exec))], false)
programs(cmd::Base.AbstractCmd) = begin
  names, files = String[], false
  for f in (:cmd, :a, :b)
    hasproperty(cmd, f) || continue
    x = getproperty(cmd, f)
    x isa Base.AbstractCmd || continue
    n, w = programs(x)
    append!(names, n)
    files |= w
  end
  # A command whose output goes to a file, or whose input comes from one
  files |= hasproperty(cmd, :handle) && !(getproperty(cmd, :handle) isa Union{Base.DevNull,Nothing})
  (unique!(names), files)
end

"The action of starting the command `cmd`"
run_action(cmd::Base.AbstractCmd) = begin
  names, files = programs(cmd)
  what = isempty(names) ? "a program" : length(names) == 1 ? "the program $(names[1])" : "the programs " * join(names, ", ", " and ")
  Action("run $(join(names, ", "))$(files ? " with files" : "")", "run $what$(files ? ", with files of your Mac" : "")")
end

"""
The path of `p`, as the call will open it, or nothing when the sandbox can't be
sure of it: a path of the page's own kind could say one name to the sandbox and
another to the call. A String and a path of URI.jl are sure.
"""
sure_path(@nospecialize(p)) =
  p isa Union{String,SubString{String}} ? String(p) :
  nameof(typeof(p)) === :FSPath && open_module(maker(p)) ? string(p) : nothing

"""
What the call of `f`, a function that reads or changes a file, does with
`args`: nothing when it reads a file of the site's own folder, or works with
a stream that the code has.
"""
place_action(c::Context, @nospecialize(f), @nospecialize(args::Tuple)) = begin
  kw = nothing
  # A call with keywords comes here with the keywords first
  if !isempty(args) && args[1] isa NamedTuple
    kw, args = args[1], args[2:end]
  end
  n = nameof(f)
  target = !isempty(args) && args[1] isa Function ? args[2:end] : args
  # With no path, a call like readdir() reads the folder that the code works in
  isempty(target) && return n in (:mktemp, :mktempdir, :readline, :readlines, :eachline, :read, :readchomp) ? nothing :
                             reads_action(c, pwd())
  p = target[1]
  (p isa IO || p isa Base.DevNull) && return nothing
  p isa Base.AbstractCmd && return run_action(p)
  p isa Union{Number,Type,Symbol,Nothing} && return nothing
  path = sure_path(p)
  path === nothing && return Action("path $(nameof(typeof(p)))", "use a file named by a $(nameof(typeof(p))), which the sandbox can't read for sure")
  path = full_path(path)
  if n in (:cp, :mv, :rename, :symlink, :hardlink, :sendfile, :cptree, :samefile) && length(target) >= 2
    to = sure_path(target[2])
    to === nothing && return Action("path $(nameof(typeof(target[2])))", "use a file named by a $(nameof(typeof(target[2]))), which the sandbox can't read for sure")
    to = full_path(to)
    n === :samefile && return something(reads_action(c, path), reads_action(c, to), Some(nothing))
    # A move takes the file away from where it was, and a copy reads it
    from = n in (:mv, :rename) ? Action("change files in $(folder_key(path))", "move $(place_words(path))") : reads_action(c, path)
    from === nothing || c.site.answer(from.key) === true || return from
    return Action("change files in $(folder_key(to))", "$(CHANGES[n]) $(place_words(to))")
  end
  writes = haskey(CHANGES, n) || (n === :open && opens_to_write(target, kw))
  writes && return Action("change files in $(folder_key(path))", "$(get(CHANGES, n, "write to")) $(place_words(path))")
  reads_action(c, path)
end

"The action of reading the file or the folder at `path`, a full path: nothing when it's in the site's own folder"
reads_action(c::Context, path::AbstractString) =
  inside(full_path(path), full_path(c.site.folder)) ? nothing : Action("read files in $(folder_key(path))", "read $(place_words(path))")

# --- loading packages ---

"""
What a page's code that loads a package does: nothing when the package is one
that a page may load, as it's on this Mac and loaded already.
"""
load_action(c::Context, @nospecialize(f), @nospecialize(args::Tuple)) = begin
  if isdefined(@__MODULE__, :Kip) && f === Kip.require
    return use_action(args[1])
  end
  # Base._eval_import(imported, to, from, paths...) and Base._eval_using(to, path)
  to = f === Base._eval_import ? args[2] : args[1]
  to isa Module && !owned(c, to) && return Action("change $(join(fullname(to), '.'))", "change $(join(fullname(to), '.')), a part of $(whose(to))")
  paths = f === Base._eval_import ? (args[3] === nothing ? args[4:end] : (args[3],)) : (args[2],)
  for p in paths
    a = import_action(c, p)
    a === nothing || return a
  end
  nothing
end

"The first name of the path of a `using` or `import`, like :Base for Base.Iterators, or nothing for one of the page's own modules"
import_root(p) = begin
  p isa Expr && p.head === :(.) || return nothing
  first = p.args[1]
  first === :(.) ? nothing : first isa Symbol ? first : nothing
end

import_action(c::Context, p) = begin
  p isa QuoteNode && (p = p.value)
  Meta.isexpr(p, :as) && (p = p.args[1])
  Meta.isexpr(p, :(:)) && (p = p.args[1])
  root = import_root(p)
  root === nothing && return nothing
  root in (:Base, :Core) && return nothing
  isdefined(c.m, root) && Base.invokelatest(getglobal, c.m, root) isa Module && return nothing
  loaded(root) && return nothing
  # A package of Julia's own, like Statistics, is Julia's code
  (root in OPEN_STDLIBS || isdir(joinpath(Sys.STDLIB, string(root)))) && return nothing
  Action("package $root", "install and load the package $root")
end

"True when Julia has loaded the package called `name`"
loaded(name::Symbol) = any(m -> nameof(m) === name, Base.loaded_modules_array())

"""
What `@use spec` does: nothing when it loads a package of GitHub that's on
this Mac, or one that Julia has loaded.
"""
use_action(spec) = begin
  spec isa Symbol && return loaded(spec) ? nothing : Action("package $spec", "install and load the package $spec")
  spec isa AbstractString || return Action("load code", "load code that the sandbox can't check first")
  m = isdefined(@__MODULE__, :Kip) ? match(Kip.gh_shorthand, spec) : nothing
  if m !== nothing
    user, repo = m.captures[1], m.captures[2]
    isdir(joinpath(Kip.repos, user, repo)) && return nothing
    return Action("package github.com/$user/$repo", "load the package $user/$repo from GitHub, which isn't on your Mac yet")
  end
  Action("code $spec", "run the code of $(basename(spec)) outside the sandbox")
end

"True when `x`, an argument of `@use` after its first, only names what the package gives: `name`, `@macro`, `a => b` or `name...`"
names_only(x) = x isa Symbol || x isa LineNumberNode ||
  Meta.isexpr(x, :macrocall) && length(x.args) <= 2 ||
  Meta.isexpr(x, :call) && length(x.args) == 3 && x.args[1] === :(=>) && x.args[2] isa Symbol && x.args[3] isa Symbol ||
  Meta.isexpr(x, :...) && length(x.args) == 1 && x.args[1] isa Symbol

"The package or the file that `@use` is given in `ex`, its first argument after the macro's name and line"
use_spec(ex::Expr) = begin
  x = length(ex.args) >= 3 ? ex.args[3] : nothing
  # A list of packages, or a package with a list in brackets, isn't one that the sandbox can check
  (Meta.isexpr(x, :tuple) || Meta.isexpr(x, :vect) || Meta.isexpr(x, :vcat) || Meta.isexpr(x, :hcat)) && return nothing
  while x isa Expr
    x = x.head === :call && length(x.args) >= 2 && x.args[1] in (:(=>), :(:)) ? x.args[2] :
        x.head in (:..., :(.), :(:), :tuple) && !isempty(x.args) ? x.args[1] : nothing
  end
  x
end

# --- changing the code ---

"""
Refuse to run the code: the step that does `a`. The code that `guard!`
changed calls this where it took out a step that the sandbox can't check,
like a call of C code.
"""
refuse(c::Context, a::Action) = permit(c, a)

const CALL = GlobalRef(@__MODULE__, :call)
const FREE_CALL = GlobalRef(@__MODULE__, :free_call)
const GOT_CALL = GlobalRef(@__MODULE__, :got_call)
const CALL_TO_CALL = GlobalRef(@__MODULE__, :call_to_call)
const LOOK = GlobalRef(@__MODULE__, :look)
const LOOK_TO_CALL = GlobalRef(@__MODULE__, :look_to_call)
const REFUSE = GlobalRef(@__MODULE__, :refuse)
const SIGNATURE = GlobalRef(@__MODULE__, :signature)

"A step that refuses to run, in place of `s`, unless you said yes to `a`"
refusal(c::Context, a::Action, s) = c.site.answer(a.key) === true ? s : Expr(:call, REFUSE, QuoteNode(c), QuoteNode(a))

"""
Change the lowered code `ci` of a page of `c` so that each call is checked as
it runs, and each name that it reads: see the top of this file. The code of
each function that it defines is changed too.
"""
guard!(c::Context, ci::Core.CodeInfo) = begin
  code = ci.code
  sigs = Set{Int}()   # the steps that make the signature of a method
  for s in code
    Meta.isexpr(s, :method) && length(s.args) == 3 && s.args[2] isa Core.SSAValue && push!(sigs, s.args[2].id)
  end
  called, other = Set{Int}(), Set{Int}()
  foreach(s -> uses!(called, other, s, false), code)
  known = Dict{Int,Any}()   # the value of each step that reads a constant, which stays as it is
  for i in eachindex(code)
    s = code[i]
    code[i] = step(c, s, i in sigs, i in called && !(i in other), known)
    s isa GlobalRef && code[i] === s && (v = constant(s)) !== nothing && (known[i] = something(v))
  end
  ci
end

"The value of the name `g`, as `Some`, when it's a constant that's defined now, or nothing"
constant(g::GlobalRef) =
  Base.invokelatest(isdefined, g.mod, g.name) && Base.invokelatest(isconst, g.mod, g.name) ?
    Some(Base.invokelatest(getglobal, g.mod, g.name)) : nothing

"The function that the step `x` calls, as `Some`, when the sandbox knows it now: a constant, or a step that reads one"
callee(x, known::Dict{Int,Any}) =
  x isa GlobalRef ? constant(x) :
  x isa Core.SSAValue ? (haskey(known, x.id) ? Some(known[x.id]) : nothing) :
  x isa QuoteNode ? Some(x.value) :
  x isa Function ? Some(x) : nothing

"True when the page's code can call `f` with only its arguments checked"
free(c::Context, f) = owned(c, f) ? !(f isa Function && nameof(f) in (:eval, :include)) : calling(f) === :free

"Note each step whose value `x` uses: in `called` when it calls the value, and in `other` when it uses the value any other way"
uses!(called::Set{Int}, other::Set{Int}, x, callee::Bool) = begin
  if x isa Core.SSAValue
    push!(callee ? called : other, x.id)
  elseif x isa Expr
    for (i, a) in enumerate(x.args)
      uses!(called, other, a, x.head === :call && i == 1)
    end
  elseif x isa Core.ReturnNode
    isdefined(x, :val) && uses!(called, other, x.val, false)
  elseif x isa Core.GotoIfNot
    uses!(called, other, x.cond, false)
  elseif x isa Core.PiNode
    uses!(called, other, x.val, false)
  end
  nothing
end

"The step `s`, changed for the sandbox. `sig` is true when it makes the signature of a method, and `to_call` when the code only calls its value."
step(c::Context, s, sig::Bool=false, to_call::Bool=false, known=Dict{Int,Any}()) =
  s isa GlobalRef ? reads(c, s, to_call) :
  s isa Expr ? expr_step(c, s, sig, to_call, known) :
  s isa Core.ReturnNode && isdefined(s, :val) && s.val isa GlobalRef ? (reads(c, s.val) === s.val ? s : (eager(c, s.val); s)) :
  s isa Core.GotoIfNot && s.cond isa GlobalRef ? (reads(c, s.cond) === s.cond ? s : (eager(c, s.cond); s)) :
  s

"A name that the code reads where a check can't go, in a return or a jump: the code can't run unless you said yes to it"
eager(c::Context, g::GlobalRef) =
  permit(c, Action("code", "read $(g.name) in a way that the sandbox can't check"))

"""
The step that reads the name `g`: `g` itself when it's a constant that the
page's code may hold, and otherwise a check of what it holds as the code runs.
"""
reads(c::Context, g::GlobalRef, to_call::Bool=false) = begin
  if Base.invokelatest(isdefined, g.mod, g.name) && Base.invokelatest(isconst, g.mod, g.name)
    v = Base.invokelatest(getglobal, g.mod, g.name)
    holds(c, g.mod, g.name, v, !to_call) && return g
  end
  Expr(:call, to_call ? LOOK_TO_CALL : LOOK, QuoteNode(c), QuoteNode(g.mod), QuoteNode(g.name))
end

"True when `ci`, the code of a method, makes code as it's compiled, which the sandbox can't check"
generated(ci::Core.CodeInfo) = any(s -> Meta.isexpr(s, :meta) && !isempty(s.args) && s.args[1] in (:generated, :generated_only), ci.code)

"The action of naming `g` in a module that isn't the page's"
foreign_name(c::Context, g::GlobalRef) =
  Action("change $(join(fullname(g.mod), '.'))", "change $(join(fullname(g.mod), '.')).$(g.name), a part of $(whose(g.mod))")

expr_step(c::Context, s::Expr, sig::Bool, to_call::Bool=false, known=Dict{Int,Any}()) = begin
  h = s.head
  if h === :call
    sig && return Expr(:call, SIGNATURE, QuoteNode(c), s.args[2:end]...)
    f = callee(s.args[1], known)
    f !== nothing && free(c, something(f)) && return Expr(:call, FREE_CALL, QuoteNode(c), QuoteNode(something(f)), s.args...)
    f !== nothing && any(x -> x === something(f), GETTERS) && length(s.args) >= 2 &&
      return Expr(:call, GOT_CALL, QuoteNode(c), !to_call, QuoteNode(something(f)), s.args...)
    return Expr(:call, to_call ? CALL_TO_CALL : CALL, QuoteNode(c), s.args...)
  elseif h === :(=)
    lhs, rhs = s.args
    lhs isa GlobalRef && !owned(c, lhs.mod) && return refusal(c, foreign_name(c, lhs), s)
    rhs = rhs isa GlobalRef ? reads(c, rhs) : rhs isa Expr ? expr_step(c, rhs, false, false, known) : rhs
    return Expr(:(=), lhs, rhs)
  elseif h === :method
    name = s.args[1]
    name isa GlobalRef && !owned(c, name.mod) && return refusal(c, foreign_name(c, name), s)
    if length(s.args) == 3 && s.args[3] isa Core.CodeInfo
      generated(s.args[3]) && return refusal(c, Action("generated", "make code as it runs, which the sandbox can't check"), s)
      guard!(c, s.args[3])
    end
    return s
  elseif h === :thunk
    s.args[1] isa Core.CodeInfo && guard!(c, s.args[1])
    return s
  elseif h === :foreigncall || h === :cfunction
    return refusal(c, Action("ccall", "call C code, which can do anything that a program on your Mac can do"), s)
  elseif h === :new_opaque_closure
    return refusal(c, Action("generated", "make code as it runs, which the sandbox can't check"), s)
  elseif h === :inbounds || h === :loopinfo
    # Checks of each index stay on, so the code can't reach past the end of a list
    return nothing
  elseif h === :boundscheck
    return true
  elseif h === :meta && any(a -> a === :purity || Meta.isexpr(a, :purity), s.args)
    # What the code says of its own effects could let Julia leave out a check
    return nothing
  elseif h === :toplevel || h === :module
    # Julia would run it as code of its own, which the sandbox didn't change
    return refusal(c, Action("code $h", "run code that the sandbox can't check first"), s)
  elseif h in (:const, :global, :globaldecl)
    for g in s.args
      g isa GlobalRef && !owned(c, g.mod) && return refusal(c, foreign_name(c, g), s)
    end
    return s
  end
  s
end

"""
Make the signature of a method that the page's code defines, as `Core.svec`
does, if the sandbox lets it. A method of a function that the page didn't
make must be for a type that the page made: otherwise it would change how
the function works for all of Ladder.
"""
signature(c::Context, types::Core.SimpleVector, rest...) = begin
  isempty(types) || mine(c, types[1]) || any(t -> mine(c, t), types[2:end]) || begin
    F = types[1]
    f = F isa DataType && isdefined(F, :instance) ? F.instance : F
    n = f isa Type && F <: Type ? full_name(F.parameters[1]) : full_name(f)
    permit(c, Action("method $n", "change how $n works, for every page and for Ladder itself"))
  end
  Core.svec(types, rest...)
end
signature(c::Context, args...) = Core.svec(args...)

"True when the type `t`, or a type that it has in it, like the T of Vector{T}, is one that the page made"
mine(c::Context, t) = begin
  t isa TypeVar && return mine(c, t.ub)
  t isa UnionAll && return mine(c, Base.unwrap_unionall(t))
  # A method for a Union works for each of its types, so each must be the page's
  t isa Union && return mine(c, t.a) && mine(c, t.b)
  t isa DataType || return false
  (t.name.module === c.m || t.name.module in c.also) && return true
  # Type{T} for a constructor, Vararg{T} and the like
  any(p -> mine(c, p), t.parameters)
end

# --- running code ---

"The kinds of expression that code as it's written never has, which only a macro could write, and which the sandbox can't check after Julia lowers them"
const NOT_WRITTEN = (:new, :splatnew, :foreigncall, :cfunction, :thunk, :method, :static_parameter, :new_opaque_closure,
                     :toplevel, :module, :boundscheck, :inbounds, :loopinfo, :copyast, :latestworld, :globaldecl, :enter,
                     :leave, :pop_exception, :the_exception, :isdefined, :throw_undef_if_not, :gc_preserve_begin,
                     :gc_preserve_end, :cconv, :invoke, :code_coverage_effect)

"""
The code `ex` of a page, as it's written, checked before Julia lowers it, since
a macro runs as Julia lowers the code. A macro of the page's own runs here, in
the sandbox, and what it writes is checked in the same way. A macro of a
package that a page may use runs as Julia lowers the code, and any other needs
your yes. `@use` loads a package, so it's only for a line of its own.
"""
written(c::Context, ex) = begin
  if ex isa GlobalRef
    # Only a macro writes a GlobalRef, so the name must be one that the page may hold
    Base.invokelatest(isdefined, ex.mod, ex.name) && holds(c, ex.mod, ex.name, Base.invokelatest(getglobal, ex.mod, ex.name), true) ||
      permit(c, Action("code", "read $(ex.name) in a way that the sandbox can't check"))
    return ex
  end
  ex isa Expr || return ex
  h = ex.head
  h in NOT_WRITTEN && permit(c, Action("code $h", "run code that the sandbox can't check first"))
  # A quote is data, but what's put in it with $ runs
  h in (:quote, :inert) && return Expr(h, map(a -> quoted(c, a), ex.args)...)
  if h === :macrocall
    f = macro_function(c, ex.args[1])
    f === nothing && return ex   # Julia says that there's no such macro
    if owned(c, f)
      expanded = Base.invokelatest(macroexpand, c.m, ex; recursive=false)
      return written(c, expanded)
    end
    isdefined(@__MODULE__, :Kip) && f === Kip.var"@use" &&
      permit(c, Action("load code", "load a package from inside other code"))
    calling(f) === :free || permit(c, shut_action(f))
    # The macro gets its arguments as they're written, with each macro of the page's own in them expanded
    return Expr(h, ex.args[1:min(2, end)]..., map(a -> written(c, a), ex.args[3:end])...)
  end
  Expr(h, map(a -> written(c, a), ex.args)...)
end

"The part `x` of a quote: only what's put in it with \$ is code"
quoted(c::Context, x) =
  Meta.isexpr(x, :$) ? Expr(:$, map(a -> written(c, a), x.args)...) :
  x isa Expr && !(x.head in (:quote, :inert)) ? Expr(x.head, map(a -> quoted(c, a), x.args)...) : x

"The function of the macro that `name` names in the page's module, or nothing when it names none"
macro_function(c::Context, name) = begin
  v = resolve(c, name)
  v isa Function ? v : nothing
end

resolve(c::Context, x) = begin
  if x isa Symbol
    Base.invokelatest(isdefined, c.m, x) || return nothing
    return Base.invokelatest(getglobal, c.m, x)
  elseif x isa GlobalRef
    return Base.invokelatest(isdefined, x.mod, x.name) ? Base.invokelatest(getglobal, x.mod, x.name) : nothing
  elseif Meta.isexpr(x, :(.)) && length(x.args) == 2 && x.args[2] isa QuoteNode
    m = resolve(c, x.args[1])
    m isa Module || return nothing
    owned(c, m) || open_module(m) || permit(c, module_action(m))
    name = x.args[2].value
    return Base.invokelatest(isdefined, m, name) ? Base.invokelatest(getglobal, m, name) : nothing
  end
  nothing
end

"True when `ex` is a line `@use …` of its own"
is_use(c::Context, ex) = Meta.isexpr(ex, :macrocall) && isdefined(@__MODULE__, :Kip) &&
  macro_function(c, ex.args[1]) === Kip.var"@use"

"""
Run the code `ex` of a page of `c` in its module, in the sandbox, and give
its value, as `Core.eval(c.m, ex)` would.
"""
run(c::Context, ex) = begin
  ex isa LineNumberNode && return nothing
  if Meta.isexpr(ex, :toplevel)
    v, line = nothing, nothing
    for x in ex.args
      # Each runs in the world that the one before it made, so it sees the names that it defined
      x isa LineNumberNode ? (line = x) : (v = Base.invokelatest(run, c, line === nothing ? x : Expr(:block, line, x)))
    end
    return v
  end
  # A line `@use …` loads a package that's on this Mac, as it would in any page: see `use_action`
  inner = Meta.isexpr(ex, :block) && count(x -> !(x isa LineNumberNode), ex.args) == 1 ? last(ex.args) : ex
  Meta.isexpr(inner, :toplevel) && return run(c, inner)
  if is_use(c, inner)
    a = use_action(use_spec(inner))
    a === nothing || permit(c, a)
    # The names that it gives the page, and nothing more: a list in brackets names more files to load
    all(names_only, inner.args[4:end]) ||
      permit(c, Action("load code", "load more files of a package than its main one"))
    return Core.eval(c.m, ex)
  end
  Meta.isexpr(inner, :module) && permit(c, Action("module", "define a module, which the sandbox can't check"))
  ex = written(c, ex)
  lowered = Base.invokelatest(Meta.lower, c.m, ex)
  lowered isa Expr || return lowered isa Symbol ? look(c, c.m, lowered) : lowered isa GlobalRef ? look(c, lowered.mod, lowered.name) :
                             lowered isa QuoteNode ? lowered.value : lowered
  h = lowered.head
  h === :thunk && return (guard!(c, lowered.args[1]); Core.eval(c.m, lowered))
  h === :toplevel && return run(c, lowered)
  h in (:error, :incomplete) && return Core.eval(c.m, lowered)
  permit(c, Action("code $h", "run code that the sandbox can't check first"))
end

"Run each top-level expression of the code `code` of the page at `path` in the sandbox, as `include_string` would, with `map` given each first"
run_code(c::Context, code::AbstractString, path::AbstractString; map=identity) = begin
  v, line = nothing, LineNumberNode(1, Symbol(path))
  for ex in Meta.parseall(code; filename=String(path)).args
    ex isa LineNumberNode && (line = ex; continue)
    v = Base.invokelatest(run, c, Expr(:block, line, map(ex)))
  end
  v
end
