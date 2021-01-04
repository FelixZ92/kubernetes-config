# Local Cluster
- ensure a local nfs server is running and can be accessed from subnet 192.168.0.0/24, e.g.
````
$ cat /etc/exports
/export/k8s-local 192.168.0.0/24(rw,sync,no_subtree_check,anonuid=1000,anongid=1000)
$ sudo mkdir -p /export/k8s-local 
$ sudo exportfs -ra && sudo service nfs-kernel-server restart

````

# Keycloak

Generate oidc client secret (uuid):
`uuidgen -r | tr -d '\n'` 

- make client role `cluster-admin` to composite with `cluster-readonly` 
  