def _download(ctx):
    os = ctx.os.name.split(" ")[0]  # linux, mac, windows

    arch = ""  # x86
    if "aarch" in ctx.os.arch or "arm" in ctx.os.arch:
        arch = "-arm"

    urls = ctx.attr.urls[os + arch]
    sha = ctx.attr.sha256[os + arch]

    stripPrefix = ""
    if ctx.attr.strip_prefix:
        stripPrefix = ctx.attr.strip_prefix[os + arch]

    ctx.report_progress("downloading")
    ctx.download_and_extract(
        urls,
        sha256 = sha,
        stripPrefix = stripPrefix,
    )

    ctx.file("WORKSPACE", """workspace(name = "{name}")""".format(name = ctx.name))
    ctx.file("BUILD", """exports_files(glob(["**"]), visibility = ["//visibility:public"])""".format(name = ctx.name))

download = repository_rule(
    implementation = _download,
    attrs = {
        "urls": attr.string_list_dict(),
        "sha256": attr.string_dict(),
        "strip_prefix": attr.string_dict(),
    },
)
