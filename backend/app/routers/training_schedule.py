# backend/app/routers/training_schedule.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from datetime import date, timedelta
import datetime

from app.db import get_db
from app.models.user import User as UserModel
from app.models.one_rep_max import Exercise as ExerciseModel
from app.models.training_schedule import TrainingPlanSchedule as TrainingPlanScheduleModel
from app.models.training_schedule import ExerciseSchedule as ExerciseScheduleModel
from app.schemas.training_schedule import (
    TrainingPlanSchedule, 
    TrainingPlanScheduleCreate, 
    TrainingPlanScheduleUpdate,
    ExerciseSchedule,
    ExerciseScheduleCreate,
    ExerciseScheduleUpdate
)

router = APIRouter(
    prefix="/users/{user_id}/training-schedule",
    tags=["training-schedule"]
)

# Pobieranie wszystkich planów treningowych użytkownika
@router.get("/", response_model=List[TrainingPlanSchedule])
def get_all_training_plans(
    user_id: int, 
    from_date: Optional[date] = None, 
    to_date: Optional[date] = None,
    db: Session = Depends(get_db)
):
    # Sprawdzenie czy użytkownik istnieje
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="Użytkownik nie znaleziony")
    
    # Przygotowanie zapytania
    query = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.user_id == user_id
    ).options(
        joinedload(TrainingPlanScheduleModel.exercises).joinedload(ExerciseScheduleModel.exercise)
    )
    
    # Dodaj filtrowanie po dacie jeśli podano
    if from_date:
        query = query.filter(TrainingPlanScheduleModel.scheduled_date >= from_date)
    if to_date:
        query = query.filter(TrainingPlanScheduleModel.scheduled_date <= to_date)
    
    # Sortuj po dacie
    training_plans = query.order_by(TrainingPlanScheduleModel.scheduled_date).all()
    
    return training_plans

# Pobieranie harmonogramu na konkretny dzień
@router.get("/day/{day_date}", response_model=List[TrainingPlanSchedule])
def get_training_plans_for_day(
    user_id: int, 
    day_date: date,
    db: Session = Depends(get_db)
):
    # Sprawdzenie czy użytkownik istnieje
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="Użytkownik nie znaleziony")
    
    # Pobierz plany treningowe na dany dzień
    training_plans = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.user_id == user_id,
        TrainingPlanScheduleModel.scheduled_date == day_date
    ).options(
        joinedload(TrainingPlanScheduleModel.exercises).joinedload(ExerciseScheduleModel.exercise)
    ).all()
    
    return training_plans

# Pobieranie harmonogramu na bieżący tydzień
@router.get("/current-week", response_model=List[TrainingPlanSchedule])
def get_training_plans_for_current_week(
    user_id: int, 
    db: Session = Depends(get_db)
):
    # Sprawdzenie czy użytkownik istnieje
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="Użytkownik nie znaleziony")
    
    # Oblicz datę początku i końca bieżącego tygodnia
    today = datetime.date.today()
    start_of_week = today - timedelta(days=today.weekday())
    end_of_week = start_of_week + timedelta(days=6)
    
    # Pobierz plany treningowe na bieżący tydzień
    training_plans = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.user_id == user_id,
        TrainingPlanScheduleModel.scheduled_date >= start_of_week,
        TrainingPlanScheduleModel.scheduled_date <= end_of_week
    ).options(
        joinedload(TrainingPlanScheduleModel.exercises).joinedload(ExerciseScheduleModel.exercise)
    ).order_by(TrainingPlanScheduleModel.scheduled_date).all()
    
    return training_plans

# Pobieranie konkretnego planu treningowego
@router.get("/{training_plan_id}", response_model=TrainingPlanSchedule)
def get_training_plan(
    user_id: int, 
    training_plan_id: int,
    db: Session = Depends(get_db)
):
    # Sprawdzenie czy użytkownik istnieje
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="Użytkownik nie znaleziony")
    
    # Pobierz plan treningowy
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.user_id == user_id,
        TrainingPlanScheduleModel.id == training_plan_id
    ).options(
        joinedload(TrainingPlanScheduleModel.exercises).joinedload(ExerciseScheduleModel.exercise)
    ).first()
    
    if not training_plan:
        raise HTTPException(status_code=404, detail="Plan treningowy nie znaleziony")
    
    return training_plan

# Tworzenie nowego planu treningowego
@router.post("/", response_model=TrainingPlanSchedule)
def create_training_plan(
    user_id: int, 
    training_plan: TrainingPlanScheduleCreate,
    db: Session = Depends(get_db)
):
    # Sprawdzenie czy użytkownik istnieje
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="Użytkownik nie znaleziony")
    
    # Sprawdź czy wszystkie ćwiczenia istnieją i należą do użytkownika
    exercise_ids = [exercise.exercise_id for exercise in training_plan.exercises]
    user_exercises = db.query(ExerciseModel).filter(
        ExerciseModel.id.in_(exercise_ids),
        ExerciseModel.user_id == user_id
    ).all()
    
    if len(user_exercises) != len(exercise_ids):
        raise HTTPException(
            status_code=400, 
            detail="Niektóre z wybranych ćwiczeń nie istnieją lub nie należą do tego użytkownika"
        )
    
    # Utwórz nowy plan treningowy
    db_training_plan = TrainingPlanScheduleModel(
        user_id=user_id,
        name=training_plan.name,
        scheduled_date=training_plan.scheduled_date,
        notes=training_plan.notes
    )
    db.add(db_training_plan)
    db.flush()
    
    # Dodaj ćwiczenia do planu
    for exercise in training_plan.exercises:
        db_exercise_schedule = ExerciseScheduleModel(
            training_plan_id=db_training_plan.id,
            exercise_id=exercise.exercise_id,
            sets=exercise.sets,
            reps=exercise.reps,
            weight=exercise.weight,
            rest_time=exercise.rest_time,
            notes=exercise.notes
        )
        db.add(db_exercise_schedule)
    
    db.commit()
    db.refresh(db_training_plan)
    
    # Załaduj relacje dla odpowiedzi
    db_training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == db_training_plan.id
    ).options(
        joinedload(TrainingPlanScheduleModel.exercises).joinedload(ExerciseScheduleModel.exercise)
    ).first()
    
    return db_training_plan

# Aktualizacja planu treningowego
@router.patch("/{training_plan_id}", response_model=TrainingPlanSchedule)
def update_training_plan(
    user_id: int, 
    training_plan_id: int,
    update_data: TrainingPlanScheduleUpdate,
    db: Session = Depends(get_db)
):
    # Sprawdź czy plan treningowy istnieje i należy do użytkownika
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == training_plan_id,
        TrainingPlanScheduleModel.user_id == user_id
    ).first()
    
    if not training_plan:
        raise HTTPException(status_code=404, detail="Plan treningowy nie znaleziony")
    
    # Aktualizuj dane
    update_dict = update_data.dict(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(training_plan, key, value)
    
    db.commit()
    db.refresh(training_plan)
    
    # Załaduj relacje dla odpowiedzi
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == training_plan_id
    ).options(
        joinedload(TrainingPlanScheduleModel.exercises).joinedload(ExerciseScheduleModel.exercise)
    ).first()
    
    return training_plan

# Usuwanie planu treningowego
@router.delete("/{training_plan_id}")
def delete_training_plan(
    user_id: int, 
    training_plan_id: int,
    db: Session = Depends(get_db)
):
    # Sprawdź czy plan treningowy istnieje i należy do użytkownika
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == training_plan_id,
        TrainingPlanScheduleModel.user_id == user_id
    ).first()
    
    if not training_plan:
        raise HTTPException(status_code=404, detail="Plan treningowy nie znaleziony")
    
    # Usuń plan treningowy (kaskadowe usuwanie ćwiczeń dzięki relacji)
    db.delete(training_plan)
    db.commit()
    
    return {"message": f"Plan treningowy '{training_plan.name}' został usunięty"}

# Dodawanie nowego ćwiczenia do planu
@router.post("/{training_plan_id}/exercises", response_model=ExerciseSchedule)
def add_exercise_to_plan(
    user_id: int, 
    training_plan_id: int,
    exercise: ExerciseScheduleCreate,
    db: Session = Depends(get_db)
):
    # Sprawdź czy plan treningowy istnieje i należy do użytkownika
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == training_plan_id,
        TrainingPlanScheduleModel.user_id == user_id
    ).first()
    
    if not training_plan:
        raise HTTPException(status_code=404, detail="Plan treningowy nie znaleziony")
    
    # Sprawdź czy ćwiczenie istnieje i należy do użytkownika
    db_exercise = db.query(ExerciseModel).filter(
        ExerciseModel.id == exercise.exercise_id,
        ExerciseModel.user_id == user_id
    ).first()
    
    if not db_exercise:
        raise HTTPException(status_code=404, detail="Ćwiczenie nie znalezione lub nie należy do tego użytkownika")
    
    # Utwórz nowe ćwiczenie w planie
    db_exercise_schedule = ExerciseScheduleModel(
        training_plan_id=training_plan_id,
        exercise_id=exercise.exercise_id,
        sets=exercise.sets,
        reps=exercise.reps,
        weight=exercise.weight,
        rest_time=exercise.rest_time,
        notes=exercise.notes
    )
    db.add(db_exercise_schedule)
    db.commit()
    db.refresh(db_exercise_schedule)
    
    return db_exercise_schedule

# Aktualizacja ćwiczenia w planie
@router.patch("/{training_plan_id}/exercises/{exercise_schedule_id}", response_model=ExerciseSchedule)
def update_exercise_in_plan(
    user_id: int, 
    training_plan_id: int,
    exercise_schedule_id: int,
    update_data: ExerciseScheduleUpdate,
    db: Session = Depends(get_db)
):
    # Sprawdź czy plan treningowy istnieje i należy do użytkownika
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == training_plan_id,
        TrainingPlanScheduleModel.user_id == user_id
    ).first()
    
    if not training_plan:
        raise HTTPException(status_code=404, detail="Plan treningowy nie znaleziony")
    
    # Sprawdź czy ćwiczenie w planie istnieje
    exercise_schedule = db.query(ExerciseScheduleModel).filter(
        ExerciseScheduleModel.id == exercise_schedule_id,
        ExerciseScheduleModel.training_plan_id == training_plan_id
    ).first()
    
    if not exercise_schedule:
        raise HTTPException(status_code=404, detail="Ćwiczenie w planie nie znalezione")
    
    # Aktualizuj dane
    update_dict = update_data.dict(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(exercise_schedule, key, value)
    
    db.commit()
    db.refresh(exercise_schedule)
    
    return exercise_schedule

# Usuwanie ćwiczenia z planu
@router.delete("/{training_plan_id}/exercises/{exercise_schedule_id}")
def delete_exercise_from_plan(
    user_id: int, 
    training_plan_id: int,
    exercise_schedule_id: int,
    db: Session = Depends(get_db)
):
    # Sprawdź czy plan treningowy istnieje i należy do użytkownika
    training_plan = db.query(TrainingPlanScheduleModel).filter(
        TrainingPlanScheduleModel.id == training_plan_id,
        TrainingPlanScheduleModel.user_id == user_id
    ).first()
    
    if not training_plan:
        raise HTTPException(status_code=404, detail="Plan treningowy nie znaleziony")
    
    # Sprawdź czy ćwiczenie w planie istnieje
    exercise_schedule = db.query(ExerciseScheduleModel).filter(
        ExerciseScheduleModel.id == exercise_schedule_id,
        ExerciseScheduleModel.training_plan_id == training_plan_id
    ).first()
    
    if not exercise_schedule:
        raise HTTPException(status_code=404, detail="Ćwiczenie w planie nie znalezione")
    
    # Usuń ćwiczenie z planu
    db.delete(exercise_schedule)
    db.commit()
    
    return {"message": "Ćwiczenie zostało usunięte z planu treningowego"}