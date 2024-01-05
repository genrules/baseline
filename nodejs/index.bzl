load("//run:index.bzl", "run")
load("//download:index.bzl", "download")

def nodejs_download(_ctx = None):
    download(
        name = "nodejs",
        urls = {
            "linux": ["https://nodejs.org/dist/v20.10.0/node-v20.10.0-linux-x64.tar.xz"],
            "mac-arm": ["https://nodejs.org/dist/v20.10.0/node-v20.10.0-darwin-arm64.tar.gz"],
        },
        sha256 = {
            "linux": "3fe4ec5d70c8b4ffc1461dec83ab23fc70124e137c4cbbe1ccc9d6ae6ec04a7d",
            "mac-arm": "68b93099451d77aac116cf8fce179cabcf53fec079508dc6b39d3a086fb461a8",
        },
        strip_prefix = {
            "linux": "node-v20.10.0-linux-x64",
            "mac-arm": "node-v20.10.0-darwin-arm64",
        },
    )

configure = module_extension(
    implementation = nodejs_download,
)

def nodejs(name, command, deps=[]):
    run(
        name=name,
        tool=Label("@nodejs//:bin/node"),
        command=command,
        deps=deps,
        compile=True,
    )
