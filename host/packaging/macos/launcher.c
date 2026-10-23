/*
 * The executables in "myData Host.app/Contents/MacOS": mydatad (the bundle's main executable, run by the
 * LaunchAgent) and mydata (the command the apps and install.sh run). Each replaces itself with the bundled
 * Python (exec, so launchd keeps the same pid), in isolated mode (-I: no PYTHON* variables, no user site,
 * no current folder on sys.path) and without writing bytecode (-B: the bundle is sealed by its signature;
 * every module is compiled at build time).
 *
 * Built twice by build_host_app.sh:
 *   -DMYDATA_NAME="mydatad" -DMYDATA_PYTHON="mydatad" -DMYDATA_MODULE="mydata.service.daemon"
 *   -DMYDATA_NAME="mydata"  -DMYDATA_PYTHON="python3.11" -DMYDATA_MODULE="mydata.cli"
 * MYDATA_PYTHON is the interpreter's file name in Contents/Resources/python/bin. The daemon's is a copy of
 * the interpreter named mydatad, so ps, top and Activity Monitor show the host as mydatad.
 */
#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef MYDATA_NAME
#error "define MYDATA_NAME"
#endif
#ifndef MYDATA_PYTHON
#error "define MYDATA_PYTHON"
#endif
#ifndef MYDATA_MODULE
#error "define MYDATA_MODULE"
#endif

int main(int argc, char *argv[]) {
    char exe[PATH_MAX];
    uint32_t size = sizeof exe;
    if (_NSGetExecutablePath(exe, &size) != 0) {
        fprintf(stderr, "%s: executable path too long\n", MYDATA_NAME);
        return 70;
    }
    char real[PATH_MAX];
    if (realpath(exe, real) == NULL) {
        fprintf(stderr, "%s: cannot resolve %s: %s\n", MYDATA_NAME, exe, strerror(errno));
        return 70;
    }
    char *slash = strrchr(real, '/');  /* .../Contents/MacOS/<name> */
    if (slash == NULL) return 70;
    *slash = '\0';
    char python[PATH_MAX];
    int n = snprintf(python, sizeof python, "%s/../Resources/python/bin/%s", real, MYDATA_PYTHON);
    if (n < 0 || (size_t)n >= sizeof python) {
        fprintf(stderr, "%s: path too long\n", MYDATA_NAME);
        return 70;
    }
    /* argv: name -I -B -m module, then this program's own arguments. */
    char **args = calloc((size_t)argc + 5, sizeof *args);
    if (args == NULL) return 71;
    int i = 0;
    args[i++] = MYDATA_NAME;
    args[i++] = "-I";
    args[i++] = "-B";
    args[i++] = "-m";
    args[i++] = MYDATA_MODULE;
    for (int a = 1; a < argc; a++) args[i++] = argv[a];
    args[i] = NULL;
    execv(python, args);
    fprintf(stderr, "%s: cannot run %s: %s\n", MYDATA_NAME, python, strerror(errno));
    return 71;
}
