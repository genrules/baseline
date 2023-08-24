load("//run:index.bzl", "run")

def aws(name, command, deps=[]):
    run(
        name=name,
        command="docker run --rm -it -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY amazon/aws-cli {command}".format(command=command),
        deps=deps,
    )
