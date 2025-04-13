from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional  # Dodajemy import Optional
from typing import Dict, List, Optional

from app.schemas.user import User, UserCreate, UserUpdate, WeightHistory as WeightHistorySchema
from app.schemas.user import PlanVersionChange
from app.models.one_rep_max import Exercise as ExerciseModel, Set as SetModel, WeekPlan as WeekPlanModel
from app.models.user import User as UserModel
from app.models.weight_history import WeightHistory as WeightHistoryModel
from app.db import SessionLocal, get_db
from app.routers.one_rep_max import generate_week_plan  # Import funkcji generującej plan

router = APIRouter(
    prefix="/users",
    tags=["users"]
)

@router.get("/", response_model=List[User])
def get_users(db: Session = Depends(get_db)):
    # Ładujemy relacje z exercises i weight_history
    return db.query(UserModel).options(
        joinedload(UserModel.exercises).joinedload(ExerciseModel.week_plans).joinedload(WeekPlanModel.sets),
        joinedload(UserModel.weight_history)
    ).all()

@router.get("/{user_id}", response_model=User)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = (
        db.query(UserModel)
        .options(
            joinedload(UserModel.exercises).joinedload(ExerciseModel.week_plans).joinedload(WeekPlanModel.sets),
            joinedload(UserModel.weight_history)
        )
        .filter(UserModel.id == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/", response_model=User)
def create_user(user: UserCreate, plan_version: Optional[str] = "A", db: Session = Depends(get_db)):
    if db.query(UserModel).filter(UserModel.nickname == user.nickname).first():
        raise HTTPException(status_code=400, detail="Nickname already taken")
    if user.gender not in ["M", "F"]:
        raise HTTPException(status_code=400, detail="Gender must be 'M' or 'F'")
    
    if plan_version not in ["A", "B"]:
        raise HTTPException(status_code=400, detail="Plan version must be 'A' or 'B'")

    db_user = UserModel(**user.dict())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # Generowanie domyślnych ćwiczeń dla nowego użytkownika
    default_exercises = [
        {"name": "squats", "one_rep_max": 100.0},
        {"name": "dead_lift", "one_rep_max": 100.0},
        {"name": "bench_press", "one_rep_max": 100.0}
    ]
    for ex in default_exercises:
        db_ex = ExerciseModel(name=ex["name"], one_rep_max=ex["one_rep_max"], user_id=db_user.id)
        db.add(db_ex)
    db.commit()
    
    # Generowanie planu treningowego dla wybranego plan_version
    for week in range(1, 7):
        generate_week_plan(db_user.id, week, db, plan_version)
    
    db.commit()
    return db_user

@router.patch("/{user_id}", response_model=User)
def update_user(user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)):
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    update_data = user_update.dict(exclude_unset=True)
    if "nickname" in update_data and update_data["nickname"] != user.nickname:
        if db.query(UserModel).filter(UserModel.nickname == update_data["nickname"]).first():
            raise HTTPException(status_code=400, detail="Nickname already taken")
    if "gender" in update_data and update_data["gender"] not in ["M", "F"]:
        raise HTTPException(status_code=400, detail="Gender must be 'M' or 'F'")
    for key, value in update_data.items():
        setattr(user, key, value)
    db.commit()
    db.refresh(user)
    return user

@router.delete("/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"message": f"User {user.nickname} deleted successfully"}

@router.get("/{user_id}/weight_history", response_model=List[WeightHistorySchema])
def get_weight_history(user_id: int, db: Session = Depends(get_db)):
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    history = db.query(WeightHistoryModel).filter(WeightHistoryModel.user_id == user_id).order_by(WeightHistoryModel.recorded_at.desc()).all()
    return history

@router.post("/{user_id}/weight_history", response_model=WeightHistorySchema)
def create_weight_history(user_id: int, weight: float, db: Session = Depends(get_db)):
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    weight_history = WeightHistoryModel(user_id=user_id, weight=weight)
    db.add(weight_history)
    db.commit()
    db.refresh(weight_history)
    return weight_history

@router.post("/{user_id}/change-plan", response_model=Dict[str, str], status_code=status.HTTP_200_OK)
def change_training_plan(user_id: int, plan_data: PlanVersionChange, db: Session = Depends(get_db)):
    """
    Zmiana planu treningowego użytkownika i regeneracja wszystkich planów tygodniowych.
    
    Args:
        user_id: ID użytkownika
        plan_data: Obiekt zawierający nową wersję planu (A lub B)
        db: Sesja bazy danych
    
    Returns:
        Komunikat o powodzeniu operacji
    """
    # Sprawdź, czy plan_version jest poprawny
    plan_version = plan_data.plan_version
    if plan_version not in ["A", "B"]:
        raise HTTPException(status_code=400, detail="Plan version must be 'A' or 'B'")
    
    # Sprawdź, czy użytkownik istnieje
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Sprawdź, czy plan nie jest już taki sam
    if user.plan_version == plan_version:
        return {"message": f"User already has plan version {plan_version}"}
    
    # Usuń istniejące plany tygodniowe (i powiązane serie ćwiczeń)
    # Najpierw usuń serie (sets)
    db.query(SetModel).filter(
        SetModel.week_plan_id.in_(
            db.query(WeekPlanModel.id).join(ExerciseModel).filter(ExerciseModel.user_id == user_id)
        )
    ).delete(synchronize_session=False)
    
    # Następnie usuń plany tygodniowe (week_plans)
    db.query(WeekPlanModel).filter(
        WeekPlanModel.exercise_id.in_(
            db.query(ExerciseModel.id).filter(ExerciseModel.user_id == user_id)
        )
    ).delete(synchronize_session=False)
    
    # Aktualizuj wersję planu użytkownika
    user.plan_version = plan_version
    db.commit()
    
    # Regeneruj plany tygodniowe dla wszystkich ćwiczeń użytkownika
    for week in range(1, 7):
        generate_week_plan(user_id, week, db, plan_version)
    
    return {
        "message": f"Successfully changed plan version to {plan_version} and regenerated all training plans",
        "user_id": str(user_id),
        "plan_version": plan_version
    }
    
