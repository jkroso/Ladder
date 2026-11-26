# What app.jl needs to be built into a standalone app. It goes at the top of
# app.jl, before anything else:
#
#     include("start.jl")
#
# The code at the top level of app.jl runs once, while the app is being built.
# It loads UI.jl and Ladder, and draws the editor off screen so that code
# is compiled ahead of time. `main` runs each time the app opens, and calls
# `run_app`.

using Kip

# When you double-click a file, macOS starts the app and sends it a message
# with the file to open. It doesn't pass the file as an argument. The message
# goes to an object that GLFW makes as it starts, and that object has no
# method for it, so macOS would say that the app can't open the file. This
# gives every object the method, and the method keeps the files in a list.
#
# It's a module so that its __init__ runs when the app starts. It's above
# `import GLFW` so that it runs before GLFW's, which is when the message comes.
module Opened
const libobjc = "/usr/lib/libobjc.A.dylib"

"The files that macOS asked the app to open, the first one first"
const files = String[]
"A function of GLFW that wakes the app's window, so that it sees a new file in the list. The app sets it."
const wake = Ref{Ptr{Cvoid}}(C_NULL)

sel(name) = ccall((:sel_registerName, libobjc), Ptr{Cvoid}, (Cstring,), name)
get(obj::Ptr{Cvoid}, name) = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), obj, sel(name))

"macOS calls this with the files to open: a list of the URLs of files"
function note(self::Ptr{Cvoid}, cmd::Ptr{Cvoid}, app::Ptr{Cvoid}, urls::Ptr{Cvoid})::Cvoid
  n = ccall((:objc_msgSend, libobjc), UInt, (Ptr{Cvoid}, Ptr{Cvoid}), urls, sel("count"))
  i = UInt(0)
  while i < n
    url = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt), urls, sel("objectAtIndex:"), i)
    path = get(url, "path")
    text = path == C_NULL ? Ptr{UInt8}(C_NULL) : Ptr{UInt8}(get(path, "UTF8String"))
    text == C_NULL || push!(files, unsafe_string(text))
    i += 1
  end
  wake[] == C_NULL || ccall(wake[], Cvoid, ())
  nothing
end

"Give every object the method that macOS calls with the files to open. It does nothing the second time."
function listen()
  Sys.isapple() || return
  class = ccall((:objc_getClass, libobjc), Ptr{Cvoid}, (Cstring,), "NSObject")
  ccall((:class_addMethod, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cstring), class, sel("application:openURLs:"),
        @cfunction(note, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid})), "v@:@@")
  nothing
end

__init__() = listen()
end

# The packages that wrap native libraries, loaded before UI.jl needs them
import GLFW, Skia, Fontconfig, ModernGL, Libdl

# While Julia builds an app, packages don't run their __init__ as they load.
# Julia saves those to run when the app starts. But building the app runs the
# code in app.jl, which needs them now: Kip to find UI.jl's files, the libraries
# that GLFW and Skia wrap, and so on. Running them here is harmless, since they
# run again when the app starts.
const building = ccall(:jl_generating_output, Cint, ()) == 1
const started = Set{Module}()
const stdlibs = Set(readdir(Sys.STDLIB))
"""
Run the __init__ of each package loaded so far that hasn't run it yet. Julia's
own standard libraries are left alone: they set up things like the maths
libraries, which don't take kindly to starting twice. app.jl calls this again
after it loads the example, for the packages the example loaded.
"""
start_packages() = begin
  waiting = filter(collect(values(Base.loaded_modules))) do m
    # Kip runs the __init__ of each UI.jl file itself, as it includes it
    !(m in started || m in (Core, Base, Main) || string(nameof(m)) in stdlibs ||
      Base.PkgId(m) in Base._sysimage_modules || m in values(Kip.modules)) && isdefined(m, :__init__)
  end
  # There's no record of the order they loaded in, so one that needs another
  # library loaded first just tries again after the rest
  problems = Dict{Module,Any}()
  for _ in 1:4
    failed = Module[]
    for m in waiting
      try
        # GLFW's __init__ also asks to shut GLFW down when Julia exits, which
        # Julia refuses while it builds an app. Starting GLFW is all that's needed.
        m === GLFW ? GLFW.Init() : Base.invokelatest(getfield(m, :__init__))
        push!(started, m)
      catch e
        problems[m] = e
        push!(failed, m)
      end
    end
    waiting = failed
    isempty(waiting) && break
  end
  println(stderr, "Started: ", join(sort(string.(nameof.(collect(started)))), " "))
  isempty(waiting) || error("These packages couldn't start: ",
                            join(("$m ($(sprint(showerror, problems[m])))" for m in waiting), ", "))
end
building && (Kip.__init__(); start_packages())

"""
While the app was built, each package that wraps a library found that library
in ~/.julia and remembered where. Make them forget, so that when the app starts
they look again and find the copies inside it. Skia.jl keeps its path in a
constant, so that becomes the library's own name, which finds whichever copy
Skia_jll loaded. Skia's calls were compiled with the old path, so app.jl draws
the example again after this.
"""
relocate!() = begin
  for m in values(Base.loaded_modules)
    name = string(nameof(m))
    (endswith(name, "_jll") && !(name in stdlibs)) || continue
    for g in names(m, all=true)
      endswith(string(g), "_path") && isdefined(m, g) && getglobal(m, g) isa String || continue
      try setglobal!(m, g, nothing) catch end
    end
  end
  Core.eval(Skia, :(const libskia = "@rpath/libskia.dylib"))
end

"""
Run the __init__ of each of UI.jl's files. Kip included them while the app was
built, so Julia doesn't know to run them when the app starts.
"""
start_ui() = begin
  n = 0
  for path in Kip.fallback_paths
    m = Kip.modules[path]
    isdefined(m, :__init__) || continue
    Base.invokelatest(getfield(m, :__init__))
    n += 1
  end
  n
end

"Print the error `e` that's being handled, and where it happened"
report(@nospecialize(e)) = println(stderr, "Self-test failed: ", sprint(showerror, e, catch_backtrace()))

"""
Start the app and call `open_app(args)`, which shows its window. With
`--self-test` in `args` it runs `warm_up` instead, to check that the code it
compiled while the app was built is all still there. `--libraries` then lists
the native libraries the app loaded, so the build can leave out the rest.
"""
run_app(open_app, args, warm_up) = begin
  n = start_ui()
  if "--self-test" in args
    t = try
      @elapsed warm_up()
    catch e
      report(e)
      return 1
    end
    workers = Threads.nthreads(:default)
    Core.println(Core.stdout, "Self-test passed in $(round(t, digits=2)) s. It started $n of UI.jl's files, ",
                 "with $workers worker thread", workers == 1 ? "." : "s.")
    "--libraries" in args && foreach(l -> Core.println(Core.stdout, l), Libdl.dllist())
    return 0
  end
  open_app(args)
  0
end
