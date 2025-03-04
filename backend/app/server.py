from fastapi import FastAPI
from app.db import Base, engine
from app.routers import user, one_rep_max
from app.models import User, Exercise, WeekPlan, Set, WeightHistory  # Import przez __init__.py

# Tworzymy tabele (jeśli nie istnieją) - opcjonalne, bo używamy Alembic
# Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI!"}

# Rejestracja routera exercises (one_rep_max)
app.include_router(one_rep_max.router, prefix="", tags=["exercises"])
app.include_router(user.router)