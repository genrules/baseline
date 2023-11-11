def _run(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + "_run")
    cmd = ctx.attr.command
    tool_deps = depset()
    if ctx.attr.tool:
        if "$(tool)" not in cmd:
            cmd = "$(tool) " + cmd
        cmd = cmd.replace("$(tool)", ctx.attr.tool.files.to_list().pop().path)
        tool_deps = ctx.attr.tool.files
    cmd = ctx.expand_location(cmd)
    files = depset([executable])
    if ctx.attr.compile:
        cmd = cmd.replace("$<", "$1").replace("$@", "$2")
        ctx.actions.run_shell(
            inputs=ctx.attr.deps[0].files.to_list() + tool_deps.to_list(),
            outputs=[executable], 
            arguments = [ctx.attr.deps[0].files.to_list()[0].path, executable.path],
            command = cmd,
        )
    else:
        if len(ctx.attr.deps) > 0:
            cmd = cmd.replace("$<", "$BUILD_WORKSPACE_DIRECTORY/"+ctx.attr.deps[0].files.to_list()[0].path)
        cmd = cmd.replace("$@", "$BUILD_WORKSPACE_DIRECTORY/"+executable.path)
        ctx.actions.write(executable, cmd, is_executable=True)
        files = depset([executable], transitive = [tool_deps] + [dep.files for dep in ctx.attr.deps])

    return [DefaultInfo(
            files = files,
            executable = executable,
            runfiles = ctx.runfiles(tool_deps.to_list()).merge_all([ctx.runfiles(dep.files.to_list()) for dep in ctx.attr.deps])
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
        "compile": attr.bool(),
    },
    executable = True,
)
