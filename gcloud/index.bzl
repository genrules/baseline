load("//run:index.bzl", "run")
load("//run_if:index.bzl", "run_if")
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

def fmt(name):
    return name.replace(".", "-")

def gcloud_entity(name, service, entity, options, flags="", format="", out="", id="", deps=[]):
    if not id:
        id = fmt(name)

    gcloud(
        name=name+".create",
        command="{service} {entity} create {name} {flags} {options}".format(service=service, entity=entity, name=id, flags=flags, options=options),
        deps=deps,
    )

    describe = "{service} {entity} describe {name} {flags}".format(service=service, entity=entity, name=id, flags=flags)
    if format:
        describe += " --format='{format}'".format(format=format)

    if out:
        describe += " > "+out

    gcloud(
        name=name+".describe",
        command=describe,
        deps=deps,
    )

    gcloud(
        name=name+".update",
        command="{service} {entity} update {name} {flags} {options}".format(service=service, entity=entity, name=id, options=options, flags=flags),
        deps=deps,
    )

    gcloud(
        name=name+".delete",
        command="{service} {entity} delete {name} {flags}".format(service=service, entity=entity, name=id, flags=flags),
        deps=deps,
    )

    run_if(
        name = "{name}.ensure_exists".format(name=name),
        fails = ":{name}.describe".format(name=name),
        then_run = ":{name}.create".format(name=name)
    )

    run_if(
        name = "{name}.upsert".format(name=name),
        succeeds = ":{name}.describe".format(name=name),
        then_run = ":{name}.update".format(name=name),
        else_run = ":{name}.create".format(name=name),
    )

# Run

def gcloud_run_deploy(
    name, service, image, port, region, allow_unauthenticated
):
    command = "run deploy {service} --image={image} --port={port} --region={region}".format(
        service=service, image=image, port=port, region=region
    )

    if allow_unauthenticated:
        command += " --allow-unauthenticated"

    gcloud(name, command)

# Services

def gcloud_services_enable(name, service):
    gcloud(name, "services enable {service}".format(service=service))

# Auth

def gcloud_auth_print_access_token(name, out):
    gcloud(name, "auth print-access-token > {out}".format(out=out))

# Compute

def gcloud_compute_addresses(name, format="", out=""):
    gcloud_entity(name, "compute", "addresses", "--ip-version IPV4", "--global", format=format, out=out)

def gcloud_compute_backend_buckets(name, bucket):
    gcloud_entity(name, "compute", "backend-buckets", "--gcs-bucket-name={bucket}".format(bucket = fmt(bucket)))

def gcloud_compute_url_maps(name, backend):
    gcloud_entity(name, "compute", "url-maps", "--default-backend-bucket={backend}".format(backend = fmt(backend)))

def gcloud_compute_target_http_proxies(name, map):
    gcloud_entity(name, "compute", "target-http-proxies", "--url-map={map}".format(map = fmt(map)))

def gcloud_compute_ssl_certificates(name, domain):
    gcloud_entity(name, "compute", "ssl-certificates", "--description={domain} --domains={domain}".format(domain=domain), "--global", id=fmt(domain))

def gcloud_compute_target_https_proxies(name, certificate, map):
    gcloud_entity(name, "compute", "target-https-proxies", "--url-map={map} --ssl-certificates {certificate} --global-ssl-certificates".format(certificate=fmt(certificate), map=fmt(map)), "--global")

def gcloud_compute_forwarding_rules(name, address, proxy, https=False, port="80"):
    options = "--target-http-proxy={proxy}".format(proxy=fmt(proxy))
    if https:
        options = "--target-https-proxy={proxy}".format(proxy=fmt(proxy))
        port = "443"

    gcloud_entity(name, "compute", "forwarding-rules", "--load-balancing-scheme=EXTERNAL --network-tier=PREMIUM --address={address} --ports={port} {options}".format(name=fmt(name), address=fmt(address), port=port, options=options), "--global")

# DNS

def gcloud_dns_managed_zones(name, domain):
    gcloud_entity(name, "dns", "managed-zones", "--description={domain} --dns-name={domain}".format(name=fmt(name), domain=domain))

def gcloud_dns_record_sets(name, domain, zone, ip, ttl="30", type="A"):
    gcloud_entity(name, "dns", "record-sets", "--rrdatas={ip} --ttl={ttl}".format(ip=ip.format(name=name), ttl=ttl), "--type={type} --zone={zone}".format(type=type, zone=fmt(zone)), id=domain)

# Domains

def gcloud_domains_registrations(name, domain, zone="", privacy="redacted-contact-data", price="12.00 USD", email="", phone="", country="", zip="", state="", city="", address="", contact="", validate=False):
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

    gcloud(name+".register", prefix + "$(tool) domains registrations register {domain} --cloud-dns-zone={zone} --contact-privacy={privacy} --yearly-price='{price}' {options}".format(domain=domain, zone=fmt(zone), privacy=privacy, price=price, options=options))

    gcloud(name+".describe", "domains registrations describe {domain}".format(domain=domain))

    run_if(
        name = "{name}.ensure_exists".format(name=name),
        fails = ":{name}.describe".format(name=name),
        then_run = ":{name}.register".format(name=name)
    )

# Composite rules

def gcloud_dns(name, domain, ip):
    run_all(
        name = name,
        steps = [
            ":{name}.enable_dns".format(name = name),
            ":{name}.zone.ensure_exists".format(name = name),
            ":{name}.record.ensure_exists".format(name = name),        
            ":{name}.enable_domains".format(name = name),
            ":{name}.domain.ensure_exists".format(name = name),        
        ],
    )

    gcloud_services_enable(
        name = "{name}.enable_dns".format(name=name),
        service = "dns.googleapis.com",
    )

    gcloud_dns_managed_zones(
        name = "{name}.zone".format(name = name),
        domain = domain,
    )

    gcloud_dns_record_sets(
        name = "{name}.record".format(name = name),
        zone = "{name}.zone".format(name = name),
        domain = domain,
        ip = ip,
    )

    gcloud_services_enable(
        name = "{name}.enable_domains".format(name=name),
        service = "domains.googleapis.com",
    )

    gcloud_domains_registrations(
        name = "{name}.domain".format(name = name),
        zone = "{name}.zone".format(name = name),
        domain = domain,
    )

def gcloud_ssl(name, domain, balancer):
    run_all(
        name = name,
        steps = [
            ":{name}.ssl.ensure_exists".format(name = name),
            ":{balancer}.https-proxy.ensure_exists".format(balancer = balancer),
            ":{balancer}.https-rule.ensure_exists".format(balancer = balancer),
        ],
    )

    gcloud_compute_ssl_certificates(
        name = "{name}.ssl".format(name = name),
        domain = domain,   
    )

    gcloud_compute_target_https_proxies(
        name = "{balancer}.https-proxy".format(balancer = balancer),
        map = "{balancer}.map".format(balancer = balancer),
        certificate = domain,
    )

    gcloud_compute_forwarding_rules(
        name = "{balancer}.https-rule".format(balancer = balancer),
        address = "{balancer}.address".format(balancer = balancer),
        proxy = "{balancer}.https-proxy".format(balancer = balancer),
        https = True,
    )

def gcloud_load_balancer(name, bucket_name, out):
    run_all(
        name = name,
        steps = [
            ":{name}.enable_compute".format(name = name),
            ":{name}.address.ensure_exists".format(name = name),
            ":{name}.backend.ensure_exists".format(name = name),
            ":{name}.map.ensure_exists".format(name = name),
            ":{name}.proxy.ensure_exists".format(name = name),
            ":{name}.rule.ensure_exists".format(name = name),
            ":{name}.address.describe".format(name = name),
        ],
    )

    gcloud_services_enable(
        name = "{name}.enable_compute".format(name=name),
        service = "compute.googleapis.com",
    )

    gcloud_compute_addresses(
        name = "{name}.address".format(name = name),
        format = "value(address)",
        out = out,
    )

    gcloud_compute_backend_buckets(
        name = "{name}.backend".format(name = name),
        bucket = bucket_name,
    )

    gcloud_compute_url_maps(
        name = "{name}.map".format(name = name),
        backend = "{name}.backend".format(name = name)
    )

    gcloud_compute_target_http_proxies(
        name = "{name}.proxy".format(name = name),
        map = "{name}.map".format(name = name)
    )

    gcloud_compute_forwarding_rules(
        name = "{name}.rule".format(name = name),
        address = "{name}.address".format(name = name),
        proxy = "{name}.proxy".format(name = name),
    )
