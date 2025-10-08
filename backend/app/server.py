# backend/app/server.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware  # ← DODAJ TEN IMPORT
from app.db import Base, engine
from app.routers import user, one_rep_max, training_schedule
from app.models import User, Exercise, WeekPlan, Set, WeightHistory, TrainingPlanSchedule, ExerciseSchedule

# Tworzymy tabele (jeśli nie istnieją) - opcjonalne, bo używamy Alembic
# Base.metadata.create_all(bind=engine)

app = FastAPI()

# ← DODAJ CAŁĄ TĘ SEKCJĘ TUTAJ (zaraz po utworzeniu app)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Dla testów lokalnych - w produkcji zmień na konkretne domeny
    allow_credentials=True,
    allow_methods=["*"],  # Pozwala na POST, GET, OPTIONS, DELETE, PATCH
    allow_headers=["*"],  # Pozwala na wszystkie nagłówki
)

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI!"}

# Rejestracja routerów
app.include_router(one_rep_max.router, prefix="", tags=["exercises"])
app.include_router(user.router)
app.include_router(training_schedule.router, tags=["training-schedule"])