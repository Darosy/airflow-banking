# Custom image: Airflow 3.2.2 base + provider Postgres + FAB auth manager + pandas
# Build sekali (docker compose build), dipakai ulang oleh semua service airflow-*.
FROM apache/airflow:3.2.2

COPY requirements.txt /requirements.txt

USER airflow
RUN pip install --no-cache-dir -r /requirements.txt
