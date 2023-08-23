load("//run:index.bzl", "run")
load("//download:index.bzl", "download")
load("//steps:index.bzl", "steps")

def gcloud_download():
    download(
        name = "gcloud",
        sha256 = {
            "linux": "332627b07483ed0e91155c4a9189e15bbdf1ae20265d6784f94672f566831387",
            "mac-arm": "791a18beddd6620ffd52a4d6a1e14ad5f02a9126e05e78b7250d6b55f4116beb",
        },
        urls = {
            "linux": ["https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-443.0.0-linux-x86_64.tar.gz"],
            "mac-arm": ["https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-443.0.0-darwin-arm.tar.gz"],
        },
    )


def gcloud(name, command):
    run(
        name=name,
        tool="@gcloud//:google-cloud-sdk/bin/gcloud",
        command=command,
    )

def gcloud_run_deploy(
    name, service, image, port, region, project, allow_unauthenticated
):
    command = "run deploy {service} --image={image} --port={port} --region={region} --project={project}".format(
        service=service, image=image, port=port, region=region, project=project
    )

    if allow_unauthenticated:
        command += " --allow-unauthenticated"

    gcloud(name, command)


def gcloud_services_enable(name, service, project):
    command = "services enable {service} --project={project}".format(
        service=service, project=project
    )
    gcloud(name, command)

def gcloud_auth_activate_refresh_token(name, account, token):
    gcloud(
        name=name,
        command="auth activate-refresh-token {account} {token}".format(account=account, token=token),
    )

def gcloud_auth(name):
    gcloud_auth_activate_refresh_token(name, "token", "$CLOUDSDK_AUTH_REFRESH_TOKEN")

def gcloud_auth_print_access_token(name, out):
    gcloud(name, "auth print-access-token > {out}".format(out=out))
