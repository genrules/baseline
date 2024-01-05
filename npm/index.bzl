load("//run:index.bzl", "run")

def npm(name, command, package_json="package.json", deps=[], local=False, output_directory="", compile=True):
    run(
        name=name,
        tool=Label("@nodejs//:bin/npm"),
        command="$(tool) ci && $(tool) " + command,
        deps=deps + [Label("@nodejs//:bin/node")],
        output_directory=output_directory,
        compile=compile,
        local=local,
        directory=native.package_relative_label(package_json).package,
    )
