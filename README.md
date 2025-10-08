# agro-iot-platform

This repository contains the Agro IoT Platform composed of multiple services:

- ASP.NET Core APIs (AgroAPI.API, AgroAPI.Gateway)
- Node ingestion service (`api-services`)
- MongoDB and Microsoft SQL Server (optional, managed via Docker)

This README explains how to prepare the environment, configure per-developer secrets, run the full stack with Docker Compose and test the main flows.

## Prerequisites

- Docker Desktop (with WSL2 backend recommended) installed and running.
- PowerShell (Windows) or a shell that can run the included `deploy.ps1` script.
- Git to clone the repository.

## Per-developer configuration

Do NOT commit your `.env` files. The repo contains `*.env.example` files with placeholders. Each developer should create their own local `.env`.

1. Copy the example env into place:

```powershell
Copy-Item .\services\.env.example .\services\.env
```

2. Edit `services/.env` and set at least:

- `SA_PASSWORD` — strong password for SQL Server when using Docker-managed SQL.
- `SQL_CONN_STR` — if you want to override runtime connection string. For Docker-managed SQL use:

	```
	SQL_CONN_STR=Server=sqlserver;Database=AgroIoT_Parcelas;User Id=sa;Password=REPLACE_WITH_STRONG_PASSWORD;TrustServerCertificate=True;
	```

	If you want containers to connect to a DB running on your host machine (not recommended for sharing), use `host.docker.internal`:

	```
	SQL_CONN_STR=Server=host.docker.internal;Database=AgroIoT_Parcelas;User Id=<user>;Password=<pass>;TrustServerCertificate=True;
	```

3. For the Node ingestion service (optional) copy its example too:

```powershell
Copy-Item .\services\api-services\.env.example .\services\api-services\.env
```

## Single-command deploy (development)

The repository includes `deploy.ps1` which builds images, starts docker-compose and optionally runs EF Core migrations.

- To run the full stack using Docker-managed databases (recommended for devs who do not want to install DBs locally):

```powershell
.\deploy.ps1 -ManagedDb
```

- To run the stack but assume DBs are external (do not start SQL/Mongo via compose):

```powershell
.\deploy.ps1
```

- To force recreate the `.env` from `.env.example` (overwrites `.env`) and start managed DBs:

```powershell
.\deploy.ps1 -Force -ManagedDb
```

What the script does:
- Validates Docker is available.
- Copies `.env.example` → `.env` if missing (unless `-Force` is not set and `.env` exists).
- Runs `docker compose -f services/docker-compose.yml up -d --build` (optionally with `--profile managed-db`).
- If `-ManagedDb` is used, waits for SQL Server readiness and then runs EF migrations inside a temporary SDK container (it will not re-add the migration if it already exists).

## Useful docker-compose commands

- Show status:

```powershell
docker compose -f .\services\docker-compose.yml --project-directory .\services ps
```

- Follow logs:

```powershell
docker compose -f .\services\docker-compose.yml --project-directory .\services logs -f
```

- Tear down and remove volumes:

```powershell
docker compose -f .\services\docker-compose.yml --project-directory .\services down -v
```

## Test the main flow (Auth + protected endpoints)

After deploy (gateway exposed at http://localhost:5172), you can run simple PowerShell examples:

```powershell
$body = @{ name='Test'; email='test@example.com'; password='Password123!' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri 'http://localhost:5172/agro/auth/register' -Body $body -ContentType 'application/json'

$creds = @{ email='test@example.com'; password='Password123!' } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri 'http://localhost:5172/agro/auth/login' -Body $creds -ContentType 'application/json'
$token = $login.token

Invoke-RestMethod -Method Get -Uri 'http://localhost:5172/agro/cultivos' -Headers @{ Authorization = "Bearer $token" }
```

Adjust fields according to the actual API DTOs.

## Security & best practices

- Do not commit `.env` files. They are in `.gitignore`.
- If a secret was accidentally committed/pushed, rotate it immediately and consider using a history rewrite tool (BFG/git-filter-repo) to purge it from history.
- For production, use a managed database service and a secret manager (Key Vault, Vault, Secrets Manager) rather than `.env` files.

## Troubleshooting

- If SQL Server fails to start in Docker, check the `SA_PASSWORD` complexity (MSSQL requires a complex password).
- If ports are already in use, change mappings in `services/docker-compose.yml` (e.g., change `1433:1433` to `11433:1433`).
- If migrations fail because the DB is not reachable, re-run `.\deploy.ps1 -ManagedDb` (the script waits for SQL readiness but may need a retry if environment is slow).

## Want me to do more?

- I can add a short `docs/DEV_SETUP.md` or extend this readme with screenshots / curl examples.
- I can scan git history for any commits that contain `services/.env` to determine if secrets leaked and help remove them.

---

End of developer setup guide.
