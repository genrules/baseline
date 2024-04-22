load("@genrules_local//run:index.bzl", "run")

def static(name, deps=[], output_directory="out", compile=True):
    run(
        name=name,
        command="mkdir -p " + output_directory + " && cp -Lr $(SRCS) " + output_directory,
        deps=deps,
        output_directory=output_directory,
        compile=compile,
    )
