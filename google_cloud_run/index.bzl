load("//gcloud:index.bzl", "gcloud_run_deploy", "gcloud_services_enable", "gcloud_auth_print_access_token")
load("//run_all:index.bzl", "run_all")
load("//run_if:index.bzl", "run_if")
load("//crane:index.bzl", "crane_auth_login", "crane_push")

def deploy(
    name, 
    target, 
    port = "8080", 
    region = "us-west1", 
    registry = "gcr.io",
    username = "oauth2accesstoken",
    password = "",
    repository = "",
    project = "",
    allow_unauthenticated = True,
    ):
    run_all(
        name=name,
        steps = [
            ":{name}_access_token".format(name=name),
            ":{name}_gcr_login".format(name=name),
            ":{name}_push_image".format(name=name),
            ":{name}_enable_cloud_run".format(name=name),
            ":{name}_deploy_image".format(name=name),
        ],
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

    crane_push(
        name = "{name}_push_image".format(name=name),
        target = "{target}.tar".format(target=target),
        image = "gcr.io/{project}/{repository}:latest".format(
            repository=repository if repository else name,
            project = project if project else "$GCP_PROJECT")
    )

    gcloud_services_enable(
        name = "{name}_enable_cloud_run".format(name=name),
        service = "run.googleapis.com",
        project = project if project else "$GCP_PROJECT",
    )

    gcloud_run_deploy(
        name = "{name}_deploy_image".format(name=name),
        service = "{name}".format(name=name),
        image = "gcr.io/{project}/{repository}:latest".format(
            repository=repository if repository else name,
            project = project if project else "$GCP_PROJECT"),
        port = port,
        region = region,
        project = project if project else "$GCP_PROJECT",
        allow_unauthenticated = allow_unauthenticated,
    )