load("//run:index.bzl", "run")
load("//run_all:index.bzl", "run_all")
load("//download:index.bzl", "download")

def gcloud_download(_ctx = None):
    download(
        name = "gcloud",
        urls = {
            "linux": ["https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-443.0.0-linux-x86_64.tar.gz"],
            "mac-arm": ["https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-443.0.0-darwin-arm.tar.gz"],
        },
        sha256 = {
            "linux": "332627b07483ed0e91155c4a9189e15bbdf1ae20265d6784f94672f566831387",
            "mac-arm": "791a18beddd6620ffd52a4d6a1e14ad5f02a9126e05e78b7250d6b55f4116beb",
        },
    )

configure = module_extension(
    implementation = gcloud_download,
)

def gcloud(name, command, deps=[]):
    run(
        name=name,
        tool=Label("@gcloud//:google-cloud-sdk/bin/gcloud"),
        command=command,
        deps=deps,
    )

# Run

def gcloud_run_deploy(
    name, service, image, port, region, project, allow_unauthenticated
):
    command = "run deploy {service} --image={image} --port={port} --region={region} --project={project}".format(
        service=service, image=image, port=port, region=region, project=project
    )

    if allow_unauthenticated:
        command += " --allow-unauthenticated"

    gcloud(name, command)

# Services

def gcloud_services_enable(name, service, project="$GCP_PROJECT"):
    command = "services enable {service} --project={project}".format(
        service=service, project=project
    )
    gcloud(name, command)

# Auth

def gcloud_auth_print_access_token(name, out):
    gcloud(name, "auth print-access-token > {out}".format(out=out))

# Compute

def gcloud_compute_addresses_create(name):
    gcloud(name, "compute addresses create {name} --global --ip-version IPV4".format(name=name.replace(".","-")))

def gcloud_compute_addresses_describe(name, address, out=""):
    if out:
        out = " > "+out
    gcloud(name, "compute addresses describe {address} --global --format='value(address)' {out}".format(address=address.replace(".","-"), out=out))

def gcloud_compute_backend_buckets_create(name, bucket):
    gcloud(name, "compute backend-buckets create {name} --gcs-bucket-name={bucket}".format(name=name.replace(".","-"), bucket=bucket.replace(".","-")))

def gcloud_compute_url_maps_create(name, backend):
    gcloud(name, "compute url-maps create {name} --default-backend-bucket={backend}".format(name=name.replace(".","-"), backend=backend.replace(".","-")))

def gcloud_compute_target_http_proxies_create(name, map):
    gcloud(name, "compute target-http-proxies create {name} --url-map={map}".format(name=name.replace(".","-"), map=map.replace(".","-")))

def gcloud_compute_ssl_certificates_create(name, domain):
    gcloud(name, "compute ssl-certificates create {name} --description={domain} --domains={domain} --global".format(name=domain.replace(".","-"), domain=domain))

def gcloud_compute_target_https_proxies_create(name, certificate, map):
    gcloud(name, "compute target-https-proxies create {name} --url-map={map} --ssl-certificates {certificate} --global-ssl-certificates --global".format(name=name.replace(".","-"), certificate=certificate.replace(".","-"), map=map.replace(".", "-")))

def gcloud_compute_forwarding_rules_create(name, address, proxy, https=False, port="80"):
    options = "--target-http-proxy={proxy}".format(proxy=proxy.replace(".","-"))
    if https:
        options = "--target-https-proxy={proxy}".format(proxy=proxy.replace(".","-"))
        port = "443"

    gcloud(name, "compute forwarding-rules create {name} --load-balancing-scheme=EXTERNAL --network-tier=PREMIUM --address={address} --global --ports={port} {options}".format(name=name.replace(".","-"), address=address.replace(".","-"), port=port, options=options))

# DNS

def gcloud_dns_managed_zones_create(name, domain):
    gcloud(name, "dns managed-zones create {name} --description={domain} --dns-name={domain}".format(name=name.replace(".", "-"), domain=domain))

def gcloud_dns_record_sets_create(name, domain, zone, ip, ttl="30", type="A"):
    gcloud(name, "dns record-sets create {domain} --rrdatas={ip} --ttl={ttl} --type={type} --zone={zone}".format(domain=domain, ip=ip.format(name=name), ttl=ttl, type=type, zone=zone.replace(".", "-")))


# Domains

def gcloud_domains_registrations_register(name, domain, zone="", privacy="redacted-contact-data", price="12.00 USD", email="", phone="", country="", zip="", state="", city="", address="", contact="", validate=False):
    contacts = """
allContacts:
  email: '{email}'
  phoneNumber: '{phone}'
  postalAddress:
    regionCode: '{country}'
    postalCode: '{zip}'
    administrativeArea: '{state}'
    locality: '{city}'
    addressLines: ['{address}']
    recipients: ['{contact}']
""".format(email=email, phone=phone, country=country, zip=zip, state=state, city=city, address=address, contact=contact)

    options = ""
    if price:
        options += " --quiet"
    if validate:
        options += " --validate-only"

    prefix = ""
    if email:
        options += " --contact-data-from-file=contact.yaml"
        prefix = "{{ cat >contact.yaml <<EOL{contacts}EOL\n}} && ".format(contacts=contacts)

    gcloud(name, prefix + "$(tool) domains registrations register {domain} --cloud-dns-zone={zone} --contact-privacy={privacy} --yearly-price='{price}' {options}".format(domain=domain, zone=zone.replace(".", "-"), privacy=privacy, price=price, options=options))

# Composite rules

def gcloud_dns(name, domain, ip):
    run_all(
        name = name,
        steps = [
            ":{name}.enable_dns".format(name = name),
            ":{name}.zone".format(name = name),
            ":{name}.record".format(name = name),        
            ":{name}.enable_domains".format(name = name),
            ":{name}.domain".format(name = name),        
        ],
    )

    gcloud_services_enable(
        name = "{name}.enable_dns".format(name=name),
        service = "dns.googleapis.com",
    )

    gcloud_dns_managed_zones_create(
        name = "{name}.zone".format(name = name),
        domain = domain,
    )

    gcloud_dns_record_sets_create(
        name = "{name}.record".format(name = name),
        zone = "{name}.zone".format(name = name),
        domain = domain,
        ip = ip,
    )

    gcloud_services_enable(
        name = "{name}.enable_domains".format(name=name),
        service = "domains.googleapis.com",
    )

    gcloud_domains_registrations_register(
        name = "{name}.domain".format(name = name),
        zone = "{name}.zone".format(name = name),
        domain = domain,
    )

def gcloud_ssl(name, domain, balancer):
    run_all(
        name = name,
        steps = [
            ":{name}.ssl".format(name = name),
            ":{balancer}.https-proxy".format(balancer = balancer),
            ":{balancer}.https-rule".format(balancer = balancer),
        ],
    )

    gcloud_compute_ssl_certificates_create(
        name = "{name}.ssl".format(name = name),
        domain = domain,   
    )

    gcloud_compute_target_https_proxies_create(
        name = "{balancer}.https-proxy".format(balancer = balancer),
        map = "{balancer}.map".format(balancer = balancer),
        certificate = domain,
    )

    gcloud_compute_forwarding_rules_create(
        name = "{balancer}.https-rule".format(balancer = balancer),
        address = "{balancer}.address".format(balancer = balancer),
        proxy = "{balancer}.https-proxy".format(balancer = balancer),
        https = True,
    )

# todo make this idempotent
def gcloud_load_balancer(name, bucket_name, out):
    run_all(
        name = name,
        steps = [
            ":{name}.enable_compute".format(name = name),
            ":{name}.address".format(name = name),
            ":{name}.backend".format(name = name),
            ":{name}.map".format(name = name),
            ":{name}.proxy".format(name = name),
            ":{name}.rule".format(name = name),
            ":{name}.print".format(name = name),
        ],
    )

    gcloud_services_enable(
        name = "{name}.enable_compute".format(name=name),
        service = "compute.googleapis.com",
    )

    gcloud_compute_addresses_create(
        name = "{name}.address".format(name = name),
    )

    gcloud_compute_backend_buckets_create(
        name = "{name}.backend".format(name = name),
        bucket = bucket_name,
    )

    gcloud_compute_url_maps_create(
        name = "{name}.map".format(name = name),
        backend = "{name}.backend".format(name = name)
    )

    gcloud_compute_target_http_proxies_create(
        name = "{name}.proxy".format(name = name),
        map = "{name}.map".format(name = name)
    )

    gcloud_compute_forwarding_rules_create(
        name = "{name}.rule".format(name = name),
        address = "{name}.address".format(name = name),
        proxy = "{name}.proxy".format(name = name),
    )

    gcloud_compute_addresses_describe(
        name = "{name}.print".format(name = name),
        address = "{name}.address".format(name = name),
        out = out,
    )
