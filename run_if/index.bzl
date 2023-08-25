def _run_if(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    cmd = ""
    if ctx.attr.not_empty:
        cmd = """
            if [ -n "{c}" ]
            then
                bash {t}
            elif [ -z "{e}" ]
            then
                :
                bash {e}
            fi
        """.format(
            c = ctx.attr.not_empty, 
            t = _maybe_path(ctx.attr.then_run),
            e = _maybe_path(ctx.attr.else_run))
    if ctx.attr.succeeds:
        cmd = "(bash {s} && bash {t}) || (bash {e})".format(
            s = _maybe_path(ctx.attr.succeeds), 
            t = _maybe_path(ctx.attr.then_run),
            e = _maybe_path(ctx.attr.else_run),
        )
    cmd = ctx.expand_location(cmd)
    ctx.actions.write(executable, cmd, is_executable=True)
    return [DefaultInfo(
            files = depset([executable], transitive = [
                _maybe_files(ctx.attr.then_run),
                _maybe_files(ctx.attr.else_run),
                _maybe_files(ctx.attr.succeeds),
            ]),
            executable = executable,
            runfiles = ctx.runfiles(
                _maybe_file_list(ctx.attr.then_run)+
                _maybe_file_list(ctx.attr.else_run)+
                _maybe_file_list(ctx.attr.succeeds))
        )]

def _maybe_path(attribute):
    return attribute.files.to_list().pop().short_path if attribute else ""

def _maybe_files(attribute):
    return attribute.files if attribute else depset()

def _maybe_file_list(attribute):
    return attribute.files.to_list() if attribute else []

run_if = rule(
    _run_if,
    attrs = {
        "not_empty": attr.string(),
        "succeeds": attr.label(),
        "then_run": attr.label(),
        "else_run": attr.label(),
    },
    executable = True,
)
