load("//gcloud:index.bzl", "gcloud_run_deploy", "gcloud_services_enable", "gcloud_auth_print_access_token")
load("//run_all:index.bzl", "run_all")
load("//run_if:index.bzl", "run_if")
load("//crane:index.bzl", "crane_auth_login", "crane_push", "crane_append", "crane_mutate")
load("@rules_pkg//pkg:pkg.bzl", "pkg_tar")

def deploy(
    name, 
    target = "",
    binary = "",
    tar = "",
    cmd = "",
    port = "8080", 
    region = "us-west1", 
    registry = "gcr.io",
    username = "oauth2accesstoken",
    password = "",
    repository = "",
    project = "",
    service = "",
    allow_unauthenticated = True,
    base_image = "debian",
    ):

    steps = [
        ":{name}_access_token".format(name=name),
        ":{name}_gcr_login".format(name=name),
    ]

    if target:
        steps = steps + [
            ":{name}_push_image".format(name=name),
        ]

    if binary or tar:
        steps = steps + [
            ":{name}_append".format(name=name),
            ":{name}_mutate".format(name=name),
        ]

    steps = steps + [
        ":{name}_enable_cloud_run".format(name=name),
        ":{name}_deploy_image".format(name=name),
    ]

    run_all(
        name=name,
        steps = steps,
    )

    gcloud_auth_print_access_token(
        name = "{name}_access_token".format(name=name),
        out = "~/{name}_access_token".format(name=name),
    )

    crane_auth_login(
        name = "{name}_gcr_login".format(name=name),
        registry = registry,
        user = username,
        password = password if password else "$(cat ~/{name}_access_token)".format(name=name),
    )

    image = "gcr.io/{project}/{repository}:latest".format(
            repository=repository if repository else name,
            project = project if project else "$GCP_PROJECT"
        )

    if target == "" and binary == "" and tar == "":
        print("Either target, binary, or tar is required")

    if target:
        crane_push(
            name = "{name}_push_image".format(name=name),
            target = "{target}.tar".format(target=target),
            image = image
        )

    if binary:
        pkg_tar(
            name = "{name}_tar".format(name=name),
            srcs = [binary],
            package_dir = "/"+native.package_relative_label(binary).package,
            include_runfiles = True,
        )

        crane_append(
            name = "{name}_append".format(name=name),
            tar = ":{name}_tar".format(name=name),
            base = base_image,
            image = image,
        )

        crane_mutate(
            name = "{name}_mutate".format(name=name),
            cmd = cmd if cmd else "./$(rootpath {binary})".format(binary=binary),
            image = image,
            deps = [binary],
        )

    if tar and not cmd:
        print("If tar is set, cmd is also required.")

    if tar:
        crane_append(
            name = "{name}_append".format(name=name),
            tar = tar,
            base = base_image,
            image = image,
        )

        crane_mutate(
            name = "{name}_mutate".format(name=name),
            cmd = cmd,
            image = image,
        )

    gcloud_services_enable(
        name = "{name}_enable_cloud_run".format(name=name),
        service = "run.googleapis.com",
        project = project if project else "$GCP_PROJECT",
    )

    gcloud_run_deploy(
        name = "{name}_deploy_image".format(name=name),
        service = "{service}".format(service=service if service else name.replace("_", "-")),
        image = "gcr.io/{project}/{repository}:latest".format(
            repository=repository if repository else name,
            project = project if project else "$GCP_PROJECT"),
        port = port,
        region = region,
        project = project if project else "$GCP_PROJECT",
        allow_unauthenticated = allow_unauthenticated,
    )