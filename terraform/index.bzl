load("//run:index.bzl", "run")
load("//download:index.bzl", "download")

def terraform_download(_ctx = None):
    download(
        name = "terraform",
        urls = {
            "linux": ["https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip"],
            "mac-arm": ["https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_darwin_arm64.zip"],
        },
        sha256 = {
            "linux": "d117883fd98b960c5d0f012b0d4b21801e1aea985e26949c2d1ebb39af074f00",
            "mac-arm": "01e608fc04cf54869db687a212d60f3dc3d5c828298514857f9e29f8ac1354a9",
        },
    )

configure = module_extension(
    implementation = terraform_download,
)

def terraform(name, command, srcs=[]):
    run(
        name=name,
        tool=Label("@terraform//:terraform"),
        command="ln -sf **/*.tf . && $(tool) init && $(tool) " + command,
        deps=srcs,
    )
