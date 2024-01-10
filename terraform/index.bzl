load("//run:index.bzl", "run")
load("//run_if:index.bzl", "run_if")
load("//run_all:index.bzl", "run_all")
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

def terraform(name, command="", srcs=[], deps=[], vars={}, state=True, backend_bucket="", backend_region="us-west-2", backend_key="state"):
    flags = ""
    if backend_bucket:
        flags = "-backend=true -backend-config=bucket={backend_bucket} -backend-config=key={backend_key} -backend-config=region={backend_region}".format(backend_bucket=backend_bucket,backend_key=backend_key,backend_region=backend_region)

    varFlags = ""
    for v in vars:
        varFlags += " -var=\"{key}={value}\"".format(key=v, value=vars[v])
    
    prefix = "ln -sf **/*.tf . && $(tool) init -migrate-state {flags} && $(tool) ".format(flags=flags)
    if command:
        run(
            name=name,
            tool=Label("@terraform//:terraform"),
            command=prefix + command + varFlags,
            deps=srcs + deps,
        )
    else:
        run(
            name=name+".plan",
            tool=Label("@terraform//:terraform"),
            command=prefix + "plan"+varFlags,
            deps=srcs + deps,
        )
        
        run(
            name=name+".apply",
            tool=Label("@terraform//:terraform"),
            command=prefix + "apply -auto-approve"+varFlags,
            deps=srcs + deps,
        )

        run(
            name=name+".destroy",
            tool=Label("@terraform//:terraform"),
            command=prefix + "destroy -auto-approve",
        )

        run(
            name=name+".refresh",
            tool=Label("@terraform//:terraform"),
            command=prefix + "refresh" + varFlags,
            deps=srcs + deps,
        )

        run(
            name=name+".show",
            tool=Label("@terraform//:terraform"),
            command=prefix + "show",
            deps=srcs + deps,
        )

        if backend_bucket:
            backendBucket = """
resource "aws_s3_bucket" "terraform_state_bucket" {{
  bucket = "{backend_bucket}"
}}
""".format(backend_bucket=backend_bucket)

            run(
                name=name+".backend_bucket",
                tool=Label("@terraform//:terraform"),
                command="BACKEND_TMP=backed-$RANDOM && mkdir $BACKEND_TMP && cd $BACKEND_TMP && {{ cat >backend.tf <<EOL{backendBucket}EOL\n}} && ".format(backendBucket=backendBucket)+ "$(tool) init && $(tool) apply -auto-approve && cd .. && rm -r $BACKEND_TMP",
            )

            run(
                name=name+".backend_bucket_status",
                command="HTTP_STATUS=$(curl --silent -o /dev/null --write-out \"%{{http_code}}\" https://s3.amazonaws.com/{backend_bucket}/) && echo $HTTP_STATUS".format(backend_bucket=backend_bucket),
            )

            run_if(
                name=name+".ensure_backend_bucket",
                equals=":{name}.backend_bucket_status".format(name=name),
                value="404",
                then_run=":{name}.backend_bucket".format(name=name),
            )

        steps = [ 
            name+".apply"
        ]

        if backend_bucket:
            steps = [ name+".ensure_backend_bucket" ] + steps

        run_all(
            name=name+".deploy",
            steps=steps,
        )
