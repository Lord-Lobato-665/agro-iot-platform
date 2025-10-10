Kubernetes manifests for agro-iot-platform

This folder contains a minimal set of Kubernetes manifests to run the project locally (minikube / Docker Desktop) as a starting point. They are intentionally simple — adapt replicas, resource requests, security contexts and storage classes to your cluster.

Quickstart (Docker Desktop / minikube)

1. Build images locally and tag them as used in the manifests (examples):

   # from repo root
   docker build -t services-api-services:latest -f services/api-services/Dockerfile services/api-services
   docker build -t services-agroapi-api:latest -f services/AgroService/AgroAPI.API/Dockerfile services/AgroService
   docker build -t services-agroapi-gateway:latest -f services/AgroService/AgroAPI.Gateway/Dockerfile services/AgroService

2. Create the namespace and apply manifests:

   kubectl apply -f k8s/namespace.yaml
   kubectl apply -n agro-iot -f k8s/mongo-statefulset.yaml
   kubectl apply -n agro-iot -f k8s/sqlserver-deployment.yaml
   kubectl apply -n agro-iot -f k8s/api-services-deployment.yaml
   kubectl apply -n agro-iot -f k8s/agroapi-api-deployment.yaml
   kubectl apply -n agro-iot -f k8s/agroapi-gateway-deployment.yaml

3. Expose the gateway (port-forward) to access tests locally:

   kubectl -n agro-iot port-forward svc/agroapi-gateway 5172:8080

4. Run migrations (one-off job) — example using the dotnet/sdk container and mounting code in a cluster-aware way is left as an exercise; simplest for local testing is to run migrations from your host with the connection string pointing to the cluster SQL Server service.

Notes and next steps
- Secrets: `sqlserver-secret` is a placeholder. Use sealed-secrets / external secret store for production.
- Storage: StatefulSet PVCs use the cluster's default StorageClass. Adjust size and storage class as needed.
- Health checks: I added simple readiness probes hitting `/health`. If your services don't expose that path, change them to `/` or an appropriate health endpoint.
- For production, add resource requests/limits, liveness probes, network policies, and proper image registries.

If quieres, puedo:
- Añadir un Job para ejecutar EF migrations desde un SDK container dentro del clúster automáticamente.
- Añadir manifests para ConfigMap y Secrets desde `services/.env`.
- Crear Helm chart con valores parametrizables.
 
Jobs (migraciones y tests)
-------------------------
Two example Jobs were added:

- `k8s/ef-migrations-job.yaml`: runs `dotnet ef database update` inside a `mcr.microsoft.com/dotnet/sdk:8.0` container.
   - By default it expects a `REPO_URL` environment variable set in the job spec so it can clone the repository and run migrations. Set `REPO_URL` to a public git URL, or mount your source into `/src` via a PVC.

- `k8s/smoke-tests-job.yaml`: lightweight job using `curl` to perform simple HTTP checks against the in-cluster gateway service.

Examples:

Apply the jobs (after the main services are up):

   kubectl apply -n agro-iot -f k8s/ef-migrations-job.yaml
   # Edit the Job to add REPO_URL or mount a PVC before applying if needed

   kubectl apply -n agro-iot -f k8s/smoke-tests-job.yaml
   kubectl logs -n agro-iot job/smoke-tests

Notes:
- The ef-migrations job currently exits with failure unless you set REPO_URL or mount the source. This is intentional to avoid embedding credentials in the manifest. If prefieres, puedo modify it to accept a ConfigMap with the SQL connection string and/or run as a CronJob.
