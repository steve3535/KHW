The goal of the exercise is to demonstrate the load balancer capabilities by using the elegant ingress stuff.  
- create a deployment of nginx web server with enough replicas in order to have many pods  
- have the output of the default page showing the pod name on which the curl query is directed towards  

## Traefik: one proxy to rule them all 

### Setup with Helm  

```bash
helm search repo traefik
helm repo info traefik/traefik
helm show chart traefik/traefik
helm show values traefik/traefik >/tmp/traefik.yaml
```  
**Note**: the values file is used to cstomize the setup but will be consumed after installation  

`helm install traefik traefik/traefik --values /tmp/traefik.yaml -n traefik --create-namespace`  

**Upgrade** 
`helm -n traefik upgrade traefik traefik/traefik -f /tmp/traefik.yaml`  


* A the heart of the routing: **ingress.yaml** - the name is arbitrary -
  ```bash
  spec:
  stripPrefix:
    prefixes:
      - /weissen
      - /postgres
  ---
  apiVersion: traefik.io/v1alpha1
  kind: Middleware
  metadata:
    name: redirect
  spec:
    redirectScheme:
      scheme: https
      permanent: true
      port: "443"
  ---
  apiVersion: traefik.io/v1alpha1
  kind: IngressRoute
  metadata:
    name: nginx
    namespace: internal-tools
  spec:
    entryPoints:
      - websecure
    routes:
      - match: Host(`internal-tools`)
        kind: Rule
        services:
          - name: nginx-main
            port: 80

      - match: Host(`internal-tools`) && Path(`/weissen`)
        kind: Rule
        middlewares:
          - name: strip
        services:
          - name: weissen-app-svc
            port: 5000

      - match: Host(`internal-tools`) && PathPrefix(`/pgadmin4`)
        kind: Rule
        services:
          - name: pgadmin-service
            port: 80
    tls:
        secretName: "certs"
  ---
  apiVersion: traefik.io/v1alpha1
  kind: IngressRoute
  metadata:
    name: nginx-http
    namespace: internal-tools
  spec:
    entryPoints:
      - web
    routes:
      - match: Host(`internal-tools`)
        kind: Rule
        middlewares:
          - name: redirect
        services:
          - name: nginx-main
            port: 80
  ```

* the HTTPS termination is done just by setting up a TLS secret:  
  `kubectl create secret tls certs --key certs/internal-tools.key --cert certs/internal-tools.cer --dry-run=client -o yaml >cert-secrets.yaml`
* we have the web endpoint and the web-secure endpoint 

