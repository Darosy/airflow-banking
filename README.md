# Airflow Banking ETL — Docker Compose (official Airflow 3.x, CeleryExecutor)

Basis compose ini adalah [official docker-compose Apache Airflow](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html)
(CeleryExecutor + Redis + Postgres, arsitektur Airflow 3.x dengan api-server &
dag-processor terpisah), ditambah service custom untuk case study Banking ETL.

## Struktur folder
```
airflow-banking/
├── docker-compose.yaml
├── Dockerfile                 <- extend apache/airflow:3.2.2 + provider postgres + pandas
├── requirements.txt
├── .env
├── .env-example               <- template untuk file .env
├── config/                    <- custom airflow.cfg (opsional, kosong = default)
├── include/
│   └── dataset/               <- otomatis diisi generate_banking_dataset.py
│   └── script/
│       └── generate_banking_dataset.py
│   └── sql/
│       ├── ddl_staging.sql
│       ├── ddl_dw.sql
│       ├── transform_dim_branches.sql
│       ├── transform_dim_channels.sql
│       ├── transform_dim_date.sql
│       ├── transform_dim_customers.sql
│       ├── transform_dim_accounts.sql
│       └── transform_fact_transaction.sql
├── dags/
│   ├── dag_banking_etl.py
├── logs/
└── plugins/
```

## Star Schema

![Star schema banking data warehouse](image/postgres%20-%20banking_dw%20-%20public%20-%20fact_transaction.png)

## Service yang jalan

| Service | Peran |
|---|---|
| `postgres` | metadata DB Airflow |
| `postgres-dw` | data warehouse banking (conn_id `postgres_dw`), expose `localhost:5433` |
| `redis` | broker Celery |
| `airflow-apiserver` | UI + REST API, `localhost:8080` |
| `airflow-scheduler` | scheduling task |
| `airflow-dag-processor` | parsing file DAG (terpisah dari scheduler di Airflow 3) |
| `airflow-worker` | eksekusi task (Celery worker) |
| `airflow-triggerer` | deferred task |
| `airflow-init` | sekali jalan: migrate DB, buat user, set Variable & Connection banking |
| `generate-dataset` | sekali jalan: generate 7 CSV (profile `tools`, manual trigger) |
| `flower` (opsional) | monitoring Celery, profile `flower` |
| `airflow-cli` (opsional) | akses `airflow` CLI ad-hoc, profile `debug` |

## Langkah menjalankan

1. **Copy file environment:**
   ```bash
   cp .env-example .env
   ```
   Atau di Windows (PowerShell):
   ```powershell
   Copy-Item .env-example .env
   ```

2. **Generate dataset:**
   ```bash
   docker compose run --rm generate-dataset
   ```

3. **(Khusus Linux)** samakan `AIRFLOW_UID` di `.env`:
   ```bash
   sed -i "s/^AIRFLOW_UID=.*/AIRFLOW_UID=$(id -u)/" .env
   ```
   Mac/Windows (Docker Desktop) boleh dilewati.

4. **Build custom image** (berisi `apache-airflow-providers-postgres` + `pandas`):
   ```bash
   docker compose build
   ```

5. **Init Airflow** — migrate DB, buat user admin, set Variable `banking_dataset_path`
   & Connection `postgres_dw` otomatis:
   ```bash
   docker compose up airflow-init
   ```
   Tunggu sampai muncul `Init selesai.` dan container keluar dengan exit code 0.

6. **Jalankan semua service:**
   ```bash
   docker compose up -d
   ```
   (Kalau mau nyalain Flower juga: `docker compose --profile flower up -d`)

7. **Buka UI**: http://localhost:8080 (login sesuai `.env`, default `airflow` / `airflow`).
   
   Buka **Admin → Connections → `+`** lalu isi:
   | Field | Value |
   |---|---|
   | Connection ID | `postgres_dw(bebas terserah anda)` |
   | Connection Type | `Postgres` |
   | Host | `<postgres-dw (docker local)>` |
   | Database | `banking_dw (docker local)` |
   | Login | `<banking (docker local)>` |
   | Password | `<banking123 (docker local)>` |
   | Port | `5433 (docker local)` |
   Klik **Save**.

   Cari DAG `dag_banking_etl`, unpause, klik ▶️ Trigger DAG.

8. **Cek hasil di database** (host, via psql/DBeaver):
   ```
   host: localhost | port: 5433 | db: banking_dw | user: banking | password: banking123
   ```

## Perintah berguna

```bash
# Generate ulang dataset
docker compose run --rm generate-dataset

# Lihat log salah satu service
docker compose logs -f airflow-scheduler
docker compose logs -f airflow-worker

# Masuk ke airflow CLI ad-hoc (profile debug)
docker compose run --rm airflow-cli airflow connections list

# Cek koneksi & variable yang ke-set otomatis oleh airflow-init
docker compose exec airflow-apiserver airflow connections get postgres_dw
docker compose exec airflow-apiserver airflow variables get banking_dataset_path

# Stop semua (data tetap ada di docker volume)
docker compose down

# Stop semua + HAPUS semua data (reset total)
docker compose down -v
```

## Kalau ubah requirements.txt
```bash
docker compose build
docker compose up -d --force-recreate airflow-apiserver airflow-scheduler airflow-dag-processor airflow-worker airflow-triggerer
```

## Catatan penting

- **`FERNET_KEY`** di `.env` sudah di-generate untuk dev/local. Untuk pemakaian
  di luar laptop sendiri, generate ulang key milikmu sendiri dan jangan commit
  `.env` ke git:
  ```bash
  python3 -c "import base64, os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
  ```
- **`AIRFLOW__API_AUTH__JWT_SECRET`** juga cuma nilai default dev — ganti kalau
  environment-nya bisa diakses orang lain.
- **`generate-dataset`** pakai `profiles: [tools]` — sengaja tidak ikut start
  otomatis waktu `docker compose up -d`, harus dipanggil manual via `run --rm`.
- Minimal resource yang direkomendasikan Airflow resmi: **4 GB RAM, 2 CPU, 10 GB disk**
  untuk Docker — `airflow-init` akan warning kalau kurang.
- Password `airflow`/`airflow` dan `banking123` di file ini contoh untuk
  lokal/dev saja — ganti sebelum dipakai di environment yang lebih terbuka.


------------------------------------------------------------------------------
# Superset Setup (connects to your existing DWH)

This spins up **only Superset** — no database or seeder included, since your
data warehouse already exists. Three containers:

- `superset_db` — Postgres holding Superset's own metadata (dashboards, users,
  saved charts). This is separate from your DWH.
- `redis` — caching / async query layer for Superset.
- `superset` — the Superset web app, on port 8088.

## 1. Log in

Open **http://localhost:8088**

```
username: admin
password: admin
```

Change this immediately if Superset will be reachable outside your machine.

## 2. Connect to your DWH

Settings → **Database Connections** → **+ Database**, pick your engine, and
enter your existing DWH's connection details.

**Networking depends on where your DWH lives:**

| Your DWH is... | Host to use in Superset |
|---|---|
| A managed cloud DB (RDS, Cloud SQL, Snowflake, BigQuery, etc.) | Its normal public/VPC hostname — works as-is |
| Postgres running directly on your machine (not in Docker) | `host.docker.internal` — uncomment the `extra_hosts` block in `docker-compose.yml` first |
| A container in another `docker compose` project | Put both projects on the same Docker network, then use that container's service name as host |
| Already on this same Docker network | Use its service name directly |

**Driver note:** the `apache/superset` image ships with the Postgres driver
(`psycopg2`) built in. If your DWH is MySQL, Snowflake, BigQuery, Redshift,
etc., you'll need to add the matching driver — easiest way:

```dockerfile
# Dockerfile
FROM apache/superset:latest
USER root
RUN pip install snowflake-sqlalchemy   # or mysqlclient, redshift_connector, etc.
USER superset
```

then swap `image: apache/superset:latest` for `build: .` in `docker-compose.yml`.

## 3. Build dashboards

`queries/` has the 6 reference SQL queries mapped to common banking analytics
questions (transaction trends, customer 360, branch performance, channel
usage, product performance, fraud detection) — written against the star
schema (`dim_customers`, `dim_accounts`, `dim_branches`, `dim_channels`,
`dim_date`, `fact_transaction`). Adjust table/column names if yours differ,
paste into **SQL Lab**, then save as a dataset and build charts from there.
