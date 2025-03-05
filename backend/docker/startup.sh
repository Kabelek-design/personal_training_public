#!/bin/bash

# Czekamy na dostępność bazy danych MySQL (zastąp 'db' nazwą serwisu bazy z `docker-compose.yml`)
# dockerize -wait tcp://db:3306 -timeout 20s  

# Jeśli używasz Alembic do migracji, to wykonujemy je
alembic upgrade head

# Uruchamiamy Uvicorn (w zależności od struktury aplikacji)
uvicorn app.server:app --host 0.0.0.0 --port 8000 --workers 4 --reload  

# Opcjonalne: instalujemy debuggera, jeśli chcesz debugować aplikację
pip install debugpy  
python -u -m debugpy --listen 0.0.0.0:5678 -m uvicorn --workers 4 --reload --host 0.0.0.0 --port 8000 app.server:app