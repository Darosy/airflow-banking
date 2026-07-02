"""
dag_banking_etl.py
====================
Airflow DAG untuk ETL pipeline studi kasus Banking.

Alur:
  CSV -> Extract (UPSERT ke staging, idempotent) -> Transform Load (jalankan file .sql) -> Star Schema

Perubahan dari versi sebelumnya:
  1. Staging tidak lagi "replace" tiap run, tapi UPSERT (INSERT ... ON CONFLICT DO UPDATE)
     berdasarkan primary key masing-masing tabel. Tabel staging dibuat eksplisit
     lewat sql/ddl_staging.sql (bukan auto-generate dari pandas.to_sql).
  2. Logic transform (staging -> dim/fact) dipisah ke file .sql di folder sql/,
     DAG hanya membaca & mengeksekusi file tsb -> SQL dan orchestration terpisah.

Prasyarat:
  1. Airflow Connection conn_id = "postgres_dw" (Postgres) sudah dibuat.
  2. pip install apache-airflow-providers-postgres pandas sqlalchemy
  3. Folder dataset CSV di-set lewat Airflow Variable "banking_dataset_path"
     (default: /opt/airflow/dataset).
  4. Struktur folder DAG:
       dags/
         dag_banking_etl.py
         sql/
           ddl_staging.sql
           ddl_dw.sql
           transform_dim_branches.sql
           transform_dim_channels.sql
           transform_dim_date.sql
           transform_dim_customers.sql
           transform_dim_accounts.sql
           transform_fact_transaction.sql
"""

from __future__ import annotations

import os
import pendulum
import pandas as pd

from airflow.decorators import dag, task
from airflow.models import Variable
from airflow.providers.postgres.hooks.postgres import PostgresHook

# ─── Konfigurasi ───────────────────────────────────────────────────────────
POSTGRES_CONN_ID = "postgres_dw"
SQL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql")


def get_dataset_path() -> str:
    return Variable.get("banking_dataset_path", default_var=os.path.join(os.path.dirname(__file__), "..", "include", "dataset"))


def get_engine():
    hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    return hook.get_sqlalchemy_engine()


def run_sql_file(filename: str):
    """Baca file .sql dari folder sql/ lalu eksekusi lewat PostgresHook."""
    path = os.path.join(SQL_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        sql_text = f.read()
    hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    hook.run(sql_text)


def upsert_from_csv(csv_filename: str, table: str, pk: str, cast_map: dict | None = None):
    """
    Generic extract + UPSERT:
      1. Baca CSV sebagai string apa adanya (dtype=str) -> load ke tabel temp.
      2. INSERT ... SELECT dari temp ke tabel staging dgn cast sesuai cast_map,
         ON CONFLICT (pk) DO UPDATE -> upsert, bukan replace.
      3. Drop tabel temp.

    cast_map: dict {nama_kolom: tipe_target}, mis. {"branch_id": "INT"}.
              Kolom yang tidak ada di cast_map dibiarkan sebagai TEXT.
    """
    cast_map = cast_map or {}
    path = os.path.join(get_dataset_path(), csv_filename)
    df = pd.read_csv(path, dtype=str)  # semua kolom text dulu, casting di SQL
    df = df.where(pd.notnull(df), None)

    tmp_table = f"tmp_{table}"
    engine = get_engine()
    df.to_sql(tmp_table, engine, if_exists="replace", index=False)

    cols = list(df.columns)
    select_exprs = [
        f"{c}::{cast_map[c]}" if c in cast_map else c
        for c in cols
    ]
    update_exprs = [f"{c} = EXCLUDED.{c}" for c in cols if c != pk]

    upsert_sql = f"""
        INSERT INTO {table} ({', '.join(cols)})
        SELECT {', '.join(select_exprs)}
        FROM {tmp_table}
        ON CONFLICT ({pk}) DO UPDATE SET
            {', '.join(update_exprs)};
    """

    hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    hook.run(upsert_sql)
    hook.run(f"DROP TABLE IF EXISTS {tmp_table};")
    return len(df)


@dag(
    dag_id="dag_banking_etl",
    description="ETL Banking: CSV -> Staging (UPSERT) -> Star Schema (transform via .sql files)",
    schedule=None,
    start_date=pendulum.datetime(2024, 1, 1, tz="Asia/Jakarta"),
    catchup=False,
    tags=["banking", "etl", "star-schema"],
)
def dag_banking_etl():

    # ── 0. Setup tabel staging & dw (idempotent, CREATE TABLE IF NOT EXISTS) ──
    @task
    def create_tables():
        run_sql_file("ddl_staging.sql")
        run_sql_file("ddl_dw.sql")

    # ── 1. EXTRACT: CSV -> UPSERT ke staging ────────────────────────────
    @task
    def extract_branches():
        return upsert_from_csv(
            "branches.csv", "stg_branches", pk="branch_id",
            cast_map={"branch_id": "INT"},
        )

    @task
    def extract_channels():
        return upsert_from_csv(
            "channels.csv", "stg_channels", pk="channel_id",
            cast_map={"channel_id": "INT"},
        )

    @task
    def extract_dim_date():
        return upsert_from_csv(
            "dim_date.csv", "stg_dim_date", pk="date_id",
            cast_map={
                "date_id": "INT", "year": "INT", "quarter": "INT", "month": "INT",
                "week_of_year": "INT", "day_of_month": "INT", "day_of_week": "INT",
            },
        )

    @task
    def extract_customers():
        return upsert_from_csv(
            "customers.csv", "stg_customers", pk="customer_id",
            cast_map={
                "customer_id": "INT", "branch_id": "INT",
                "credit_score": "INT", "estimated_salary": "NUMERIC",
            },
        )

    @task
    def extract_accounts():
        return upsert_from_csv(
            "accounts.csv", "stg_accounts", pk="account_id",
            cast_map={
                "account_id": "INT", "customer_id": "INT", "branch_id": "INT",
                "interest_rate": "NUMERIC",
            },
        )

    @task
    def extract_transactions():
        return upsert_from_csv(
            "transactions.csv", "stg_transactions", pk="transaction_id",
            cast_map={
                "transaction_id": "INT", "account_id": "INT", "customer_id": "INT",
                "branch_id": "INT", "channel_id": "INT",
                "amount": "NUMERIC", "balance_before": "NUMERIC", "balance_after": "NUMERIC",
            },
        )

    @task
    def extract_fraud_labels():
        return upsert_from_csv(
            "fraud_labels.csv", "stg_fraud_labels", pk="transaction_id",
            cast_map={"transaction_id": "INT", "fraud_score": "NUMERIC"},
        )

    # ── 2. TRANSFORM LOAD: jalankan file .sql (staging -> dim/fact) ─────
    @task
    def load_dim_branches(_dep=None):
        run_sql_file("transform_dim_branches.sql")

    @task
    def load_dim_channels(_dep=None):
        run_sql_file("transform_dim_channels.sql")

    @task
    def load_dim_date(_dep=None):
        run_sql_file("transform_dim_date.sql")

    @task
    def load_dim_customers(_dep=None):
        run_sql_file("transform_dim_customers.sql")

    @task
    def load_dim_accounts(_dep=None):
        run_sql_file("transform_dim_accounts.sql")

    @task
    def load_fact_transaction(_dep=None):
        run_sql_file("transform_fact_transaction.sql")

    # ── Wiring dependencies ─────────────────────────────────────────────
    setup = create_tables()

    ex_branches = extract_branches()
    ex_channels = extract_channels()
    ex_dates = extract_dim_date()
    ex_customers = extract_customers()
    ex_accounts = extract_accounts()
    ex_trx = extract_transactions()
    ex_fraud = extract_fraud_labels()

    setup >> [ex_branches, ex_channels, ex_dates, ex_customers, ex_accounts, ex_trx, ex_fraud]

    d_branch = load_dim_branches(_dep=ex_branches)
    d_channel = load_dim_channels(_dep=ex_channels)
    d_date = load_dim_date(_dep=ex_dates)
    d_customer = load_dim_customers(_dep=[ex_customers, d_branch])
    d_account = load_dim_accounts(_dep=[ex_accounts, d_customer, d_branch])

    load_fact_transaction(
        _dep=[ex_trx, ex_fraud, d_account, d_customer, d_branch, d_channel, d_date]
    )


dag_banking_etl()
