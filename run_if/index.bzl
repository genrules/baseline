def _run_if(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    cmd = """
        if [ -n "{c}" ]
        then
            {t}
        fi
    """.format(c = ctx.attr.not_empty, t = ctx.attr.then.files.to_list().pop().short_path)
    cmd = ctx.expand_location(cmd)
    ctx.actions.write(executable, cmd, is_executable=True)
    return [DefaultInfo(
            files = depset([executable]),
            executable = executable,
            runfiles = ctx.runfiles(ctx.attr.then.files.to_list())
        )]

run_if = rule(
    _run_if,
    attrs = {
        "not_empty": attr.string(),
        "then": attr.label(),
    },
    executable = True,
)
