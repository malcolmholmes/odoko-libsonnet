# Dynamic DNS With Google Cloud

This simple utility periodically checks DNS records at Google Cloud, and compares them
with the Kubernetes cluster's public IP. If they differ, the DNS at Google Cloud is
updated.

It identifies domains to check via ingress resources that have been given the
`odoko.com/dyn-dns-zone` annotation, where this specifies the name of the 'zone'
within the Google Cloud DNS.
