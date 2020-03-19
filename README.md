# Odoko Libsonnet

This is a library of Jsonnet application descriptions. At present, it is focused
on WordPress, with the install set up for `k3s`/`k3d`, and with backups/restores
working via Google Cloud Storage.

It has been used with NFS for storage on GKE. Additional resources could be added
to support that usecase.

The image handles downloading plugins and themes, either from public URLs, or
from private GCS archives.

