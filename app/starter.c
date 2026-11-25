// The program that starts an app whose image is a file of its own (APP_FORM=image in bundle.jl).
//
// It is Julia's own starter with a few more arguments: the image, which is ../lib/IMAGE from this
// program, and an empty program to run. After that program Julia calls the `main` that the image
// holds, which is app.jl's. What the app was started with comes after `--`, so Julia reads none of
// it as an option of its own.
//
// The app has Julia's own starter too, as ../bin/julia. Julia runs that one, with the same image,
// each time it compiles a cache of a package.
#include <mach-o/dyld.h>
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <libgen.h>

extern int jl_load_repl(int argc, char *argv[]);

int main(int argc, char *argv[]) {
  char raw[PATH_MAX], exe[PATH_MAX], image[PATH_MAX];
  uint32_t size = sizeof raw;
  if (_NSGetExecutablePath(raw, &size) != 0 || realpath(raw, exe) == NULL) {
    fprintf(stderr, "%s: can't find its own place\n", argv[0]);
    return 1;
  }
  snprintf(image, sizeof image, "%s/../lib/" IMAGE, dirname(exe));
  char **args = calloc(argc + 8, sizeof(char *));
  int n = 0;
  args[n++] = argv[0];
  args[n++] = "-J";
  args[n++] = image;
#ifdef THREADS
  args[n++] = "--threads=" THREADS;
#endif
  args[n++] = "-e";
  args[n++] = "";
  args[n++] = "--";
  for (int i = 1; i < argc; i++) args[n++] = argv[i];
  return jl_load_repl(n, args);
}
