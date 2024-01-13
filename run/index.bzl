def _run(ctx):
    output = None
    if ctx.attr.output_directory:
        output = ctx.actions.declare_directory(ctx.attr.output_directory)
    else:
        output = ctx.actions.declare_file(ctx.label.name + (".out" if ctx.attr.compile else ".sh"))

    cmd = ctx.attr.command
    tool_deps = depset()
    if ctx.attr.tool:
        if "$(tool)" not in cmd:
            cmd = "$(tool) " + cmd
        cmd = cmd.replace("$(tool)", "$ROOTDIR/"+ctx.attr.tool.files.to_list().pop().path)
        tool_deps = ctx.attr.tool.files
    cmd = ctx.expand_location(cmd)
    files = depset([output])

    if ctx.attr.directory:
        cmd = "export PACKAGEDIR={directory} && cd $PACKAGEDIR && ".format(directory=ctx.attr.directory) + cmd
    for t in ctx.attr.tools:
        cmd = "export PATH=$PATH:$ROOTDIR/$(dirname "+t.files.to_list().pop().path+") && " + cmd

    cmd = "export PATH=$PATH:. && " + cmd
    cmd = "export ROOTDIR=$(pwd) && " + cmd
    cmd = cmd + " && cd $ROOTDIR"

    if ctx.attr.compile:
        cmd = cmd.replace("$<", "$1").replace("$@", "$2")
        if ctx.attr.output_directory:
            cmd = cmd + " && mv $PACKAGEDIR/"+ctx.attr.output_directory+"/* $2"
        deps = []
        if len(ctx.attr.deps) > 0:
            deps = ctx.attr.deps[0].files.to_list()

        execution_requirements = {}

        if ctx.attr.local:
            execution_requirements["local"] = "true"

        ctx.actions.run_shell(
            inputs=deps + tool_deps.to_list(),
            outputs=[output], 
            arguments = [
                deps[0].path if len(deps) else "", 
                output.path, 
            ],
            command = cmd,
            execution_requirements = execution_requirements,
        )
    else:
        if len(ctx.attr.deps) > 0:
            cmd = cmd.replace("$<", "$BUILD_WORKSPACE_DIRECTORY/"+ctx.attr.deps[0].files.to_list()[0].path)
            cmd = cmd.replace("$(SRCS)", " ".join(["$BUILD_WORKSPACE_DIRECTORY/"+f.path for f in ctx.attr.deps[0].files.to_list()]))
            cmd = cmd.replace("$(SRCS_COMMA)", ",".join(["$BUILD_WORKSPACE_DIRECTORY/"+f.path for f in ctx.attr.deps[0].files.to_list()]))
        
        cmd = cmd.replace("$@", "$BUILD_WORKSPACE_DIRECTORY/"+output.path)
        ctx.actions.write(output, cmd, is_executable=True)
        files = depset([output], transitive = [tool_deps] + [dep.files for dep in ctx.attr.deps])

    return [DefaultInfo(
            files = files,
            executable = output,
            runfiles = ctx.runfiles(tool_deps.to_list()).merge_all([ctx.runfiles(dep.files.to_list()) for dep in ctx.attr.deps])
        )]

run = rule(
    _run,
    attrs = {
        "tool": attr.label(
            allow_files = True,
        ),
        "tools": attr.label_list(
            allow_files = True,
        ),
        "command": attr.string(),
        "directory": attr.string(),
        "output_directory": attr.string(),
        "deps": attr.label_list(
            allow_files = True,
        ),
        "compile": attr.bool(),
        "local": attr.bool(),
    },
    executable = True,
)
