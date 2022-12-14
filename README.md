# Local Cluster
- ensure a local nfs server is running and can be accessed from subnet 192.168.0.0/24, e.g.
````
$ cat /etc/exports
/export/k8s-local 192.168.0.0/24(rw,sync,no_subtree_check,anonuid=1000,anongid=1000)
$ sudo mkdir -p /export/k8s-local 
$ sudo exportfs -ra && sudo systemctl restart nfs-server.service

````

# Keycloak

- Add `127.0.0.1 keycloak.host.k3d.internal` to `/etc/hosts/` so redirections work also with k3d
- make client role `cluster-admin` to composite with `cluster-readonly` 
  - Clients -> k8s -> Roles -> cluster-admin 
- map client roles to groups
  - Groups -> cluster-admins -> Edit -> Role Mappings
- Set default users passwords
  - Users -> cluster-admin -> Credentials
    
