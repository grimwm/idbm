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

### Optional: s3sync

If you would like to have your WP installation and all its "uploads"
(e.g. various kinds of media files) synced with s3-compatible storage,
then you must also configure the `s3sync` container with the right
configuration. When `docker compose` is used to bring up the various
services, `s3sync` will first sync _against_ S3, and then it will sync
_to_ S3, to make sure both ends of the spectrum match. Finally, during
the normal course of operation, if new files are added or changed in WP,
they will be synced _to_ S3.

To configure `s3sync`, first create a `.env.s3sync.creds` file and place
these contents inside it:

* `S3_ACCESS_KEY_ID=<your S3 access key id>`
* `S3_SECRET_ACCESS_KEY=<your S3 secret access key>`

This repo already has a `.env.s3sync` file with non-secret information, and
you should configure that according to the s3-compatible storage you
configured. If you are using `AWS`, you most likely want to leave `S3_ENDPOINT`
empty, since the underlying S3 command typically knows what to do here.

If you are planning to run multiple `s3sync` services against various
s3-compatible cloud providers, then probably just one of them you want to
consider "primary" and define `S3_INCREMENTAL_ONLY=false` while leaving all
the "secondary" syncs with `S3_INCREMENTAL_ONLY=true` so that they don't all
clobber the local filesystem.

## Build and Test

The basic recipe for usage is:

```sh
docker compose up -d
```

You may then go to http://localhost:8080/ and access Wordpress locally. If you
opted to configure `s3sync`, then this WP installation and all of the files
uploaded to it through regular testing will be synced to the defined S3 storage
as well.

## Push Images to DOCR

After any changes here that need to be reflected in the published DOCR image,
just use the following commands:

```sh
docker compose build .
docker tag <image_id> registry.digitalocean.com/grim/wordpress:<wordpress_version>.<minor>
docker push registry.digitalocean.com/grim/wordpress:<wordpress_version>.<minor>
```

TODO: in future updates, these instructions will be modified for multi-arch support
using the information at https://docs.docker.com/desktop/multi-arch/.
