load("//gcloud:index.bzl", "gcloud", "gcloud_entity", "gcloud_load_balancer", "gcloud_dns", "gcloud_ssl", "gcloud_domains_registrations")
load("//run:index.bzl", "run")
load("//run_if:index.bzl", "run_if")
load("//run_all:index.bzl", "run_all")

def bucket(name, bucket_name):
    gcloud_entity(name, "storage", "buckets", "--uniform-bucket-level-access", id="gs://{bucket_name}/".format(bucket_name=bucket_name))

def upload(name, bucket_name, deps, delete = False, cache = "no-cache"):
    options = ""
    if delete:
        options += "--delete-unmatched-destination-objects "
    if cache:
        options += "--cache-control={cache} ".format(cache=cache)
    gcloud(
        name = name,
        command = "storage rsync --checksums-only --gzip-in-flight-all --recursive {options} $(SRCS) gs://{bucket_name}/".format(bucket_name=bucket_name, options=options),
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

def gcs_deploy(name, deps, bucket_name, domain="", domain_price="", domain_email="", domain_phone="", domain_country="", domain_zip="", domain_state="", domain_city="", domain_address="", domain_contact=""):
    steps = [
        ":{name}.bucket.ensure_exists".format(name = name),
        ":{name}.upload".format(name = name),
        ":{name}.policy".format(name = name),
        ":{name}.update_main_page".format(name = name),
        ":{name}.balancer".format(name = name),
    ]

    if domain:
        steps = steps + [
            ":{name}.dns".format(name = name),
            ":{name}.ssl".format(name = name),
        ]

    if domain_price:
        steps = steps + [
            ":{name}.domain.ensure_exists".format(name = name),
        ]

    steps = steps + [
        ":{name}.print".format(name = name),
    ]

    run_all(
        name = name,
        steps = steps,
    )

    bucket(
        name = "{name}.bucket".format(name = name),
        bucket_name = bucket_name,
    )

    upload(
        name = "{name}.upload".format(name = name),
        bucket_name = bucket_name,
        deps = deps,
    )

    add_policy(
        name = "{name}.policy".format(name = name),
        bucket_name = bucket_name,
    )

    update_main_page(
        name = "{name}.update_main_page".format(name = name),
        bucket_name = bucket_name,
    )

    gcloud_load_balancer(
        name = "{name}.balancer".format(name = name),
        bucket_name = bucket_name,
        out = "~/{name}_ip".format(name = name),
    )

    gcloud_dns(
        name = "{name}.dns".format(name = name),
        ip="$(cat ~/{name}_ip)".format(name = name),
        domain = domain,
    )

    gcloud_domains_registrations(
        name = "{name}.domain".format(name = name),
        zone = "{name}.dns.zone".format(name = name),
        domain = domain,
        price = domain_price, 
        email = domain_email, 
        phone = domain_phone, 
        country = domain_country, 
        zip = domain_zip, 
        state = domain_state, 
        city = domain_city, 
        address = domain_address, 
        contact = domain_contact
    )

    gcloud_ssl(
        name = "{name}.ssl".format(name = name),
        domain = domain,
        balancer = "{name}.balancer".format(name = name),
    )

    run(
        name = "{name}.print".format(name = name),
        command = "echo https://storage.googleapis.com/{bucket_name}/index.html?revision=$(date +\\%s) && cat ~/{name}_ip".format(name = name, bucket_name = bucket_name),
    )
