load("//gcloud:index.bzl", "gcloud")
load("//run:index.bzl", "run")
load("//run_if:index.bzl", "run_if")
load("//run_all:index.bzl", "run_all")

def create_bucket(name, bucket_name):
    gcloud(
        name = name,
        command = "storage buckets create gs://{bucket_name}/ --uniform-bucket-level-access || true".format(bucket_name=bucket_name),
    )

def upload(name, bucket_name, deps):
    gcloud(
        name = name,
        command = "storage cp -r $(SRCS) gs://{bucket_name}/".format(bucket_name=bucket_name),
        deps = deps,
    )

def add_policy(name, bucket_name, member="allUsers", role="roles/storage.objectViewer"):
    gcloud(
        name = name,
        command = "storage buckets add-iam-policy-binding gs://{bucket_name}/ --member={member} --role={role}".format(bucket_name=bucket_name, member=member, role=role),
    )

def update_main_page(name, bucket_name, main_page="index.html"):
    gcloud(
        name = name,
        command = "storage buckets update gs://{bucket_name}/ --web-main-page-suffix={main_page}".format(bucket_name=bucket_name, main_page=main_page),
    )

def gcs_deploy(name, bucket_name, deps):
    run_all(
        name = name,
        steps = [
            ":{name}_create".format(name = name),
            ":{name}_upload".format(name = name),
            ":{name}_policy".format(name = name),
            ":{name}_update_main_page".format(name = name),
            ":{name}_print".format(name = name),
        ],
    )

    create_bucket(
        name = "{name}_create".format(name = name),
        bucket_name = bucket_name,
    )

    upload(
        name = "{name}_upload".format(name = name),
        bucket_name = bucket_name,
        deps = deps,
    )

    add_policy(
        name = "{name}_policy".format(name = name),
        bucket_name = bucket_name,
    )

    update_main_page(
        name = "{name}_update_main_page".format(name = name),
        bucket_name = bucket_name,
    )

    run(
        name = "{name}_print".format(name = name),
        command = "echo https://storage.googleapis.com/{bucket_name}/index.html?revision=$(date +\\%s)".format(bucket_name = bucket_name),
    )
