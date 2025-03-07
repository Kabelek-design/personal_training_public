# backend/app/server.py
from fastapi import FastAPI
from app.db import Base, engine
from app.routers import user, one_rep_max, training_schedule
from app.models import User, Exercise, WeekPlan, Set, WeightHistory, TrainingPlanSchedule, ExerciseSchedule

# Tworzymy tabele (jeśli nie istnieją) - opcjonalne, bo używamy Alembic
# Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI!"}

# Rejestracja routerów
app.include_router(one_rep_max.router, prefix="", tags=["exercises"])
app.include_router(user.router)
app.include_router(training_schedule.router, tags=["training-schedule"])