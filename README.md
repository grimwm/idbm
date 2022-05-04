# Interior Design... by Maryam (IDBM)

This is the infrastructure-related section of IDBM. Included are instructions
on how to setup the infrastructure locally for development and, for admins
with proper access, how to push updates to the live website.

## Tools Needed

* [Docker](https://docs.docker.com/get-docker/)
* [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
* [pre-commit](https://pre-commit.com/)

## Setup

Using the tools installed above, please configure them to work with access
to DigitalOcean (DO) and log them into the DO container registry (DOCR):

    ```sh
    docker login registry.digitalocean.com

    Username: <paste-api-token>
    Password: <paste-api-token>
    ```
