def _run(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + "_run")
    cmd = ctx.attr.command
    if "$(tool)" not in cmd:
        cmd = "$(tool) " + cmd
    cmd = cmd.replace("$(tool)", ctx.attr.tool.files.to_list().pop().path)
    cmd = ctx.expand_location(cmd)
    ctx.actions.write(executable, cmd, is_executable=True)
    return [DefaultInfo(
            files = depset([executable], transitive = [ctx.attr.tool.files] + [dep.files for dep in ctx.attr.deps]),
            executable = executable,
            runfiles = ctx.runfiles(ctx.attr.tool.files.to_list()).merge_all([ctx.runfiles(dep.files.to_list()) for dep in ctx.attr.deps])
        )]

run = rule(
    _run,
    attrs = {
        "tool": attr.label(
            allow_files = True,
        ),
        "command": attr.string(),
        "deps": attr.label_list(
            allow_files = True,
        ),
    },
    executable = True,
)
