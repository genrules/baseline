
def _steps(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    cmd = ""
    runfiles = []
    for step in ctx.attr.steps: 
        # todo: figure out a less brittle way of doing this than using the last file in the list
        cmd += "bash {s} &&".format(s = step.files.to_list().pop().short_path)
        runfiles += step.files.to_list()
    cmd += "echo {name} finished!".format(name = ctx.label.name)
    cmd = ctx.expand_location(cmd)
    ctx.actions.write(executable, cmd, is_executable=True)
    return [DefaultInfo(
            files = depset([executable]),
            executable = executable,
            runfiles = ctx.runfiles(runfiles)
        )]

steps = rule(
    _steps,
    attrs = {
        "steps": attr.label_list(),
    },
    executable = True,
)
