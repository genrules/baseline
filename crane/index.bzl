load("//run:index.bzl", "run")
load("//download:index.bzl", "download")

def crane_download():
    download(
        name = "crane",
        urls = {
            "linux": ["https://github.com/google/go-containerregistry/releases/download/v0.16.1/go-containerregistry_Linux_x86_64.tar.gz"],
            "mac-arm": ["https://github.com/google/go-containerregistry/releases/download/v0.16.1/go-containerregistry_Darwin_arm64.tar.gz"],
        },
        sha256 = {
            "linux": "115dc84d14c5adc89c16e3fa297e94f06a9ec492bb1dc730da624850b77c9be2",
            "mac-arm": "3a049f448d9296e1dcd3566c5802e241bcd4e1873f998a122824655e20e0d744",
        },
    )


def crane(name, command, deps=[]):
    run(
        name=name,
        tool="@crane//:crane",
        command=command,
        deps=deps,
    )


def crane_auth_login(name, registry, user, password):
    command = "auth login {registry} -u {user} -p {password}".format(
        registry=registry, user=user, password=password
    )
    crane(name, command)


def crane_push(name, target, image):
    label = native.package_relative_label(target)
    command = "push $(rootpath {target}) {image}".format(target=label, image=image)
    crane(name, command, [label])