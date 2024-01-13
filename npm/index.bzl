load("//run:index.bzl", "run")

def npm(name, command, package_json="package.json", deps=[], local=False, output_directory="", compile=True):
    node = Label("@nodejs//:bin/node")
    run(
        name=name,
        tool=Label("@nodejs//:bin/npm"),
        tools=[node],
        command="$(tool) ci && $(tool) " + command,
        deps=deps + [node], # todo add tools to deps automatically
        output_directory=output_directory,
        compile=compile,
        local=local,
        directory=native.package_relative_label(package_json).package,
    )
