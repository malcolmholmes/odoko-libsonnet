# Odoko Libsonnet

This is a library of Jsonnet application descriptions. 

## WordPress
Currently this is set up for `k3s`/`k3d`, and with backups/restores
working via Google Cloud Storage.

It has been used with NFS for storage on GKE. Additional resources could be added
to support that usecase.

The image handles downloading plugins and themes, either from public URLs, or
from private GCS archives.

## Discourse
Similarly, Jsonnet resources could be added to install a full Discourse server with
relatively little effort.
