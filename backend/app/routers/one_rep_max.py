from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List
from typing import Dict, Any, List
from app.schemas.one_rep_max import Exercise, ExerciseCreate, Set, SetCreate, WeekPlan, WeekPlanCreate, AmrapResult
from app.models.one_rep_max import Exercise as ExerciseModel, Set as SetModel, WeekPlan as WeekPlanModel
from app.models.user import User as UserModel
from app.db import get_db

router = APIRouter(
    prefix="/users/{user_id}",
    tags=["exercises"]
)

# Pobranie listy ćwiczeń użytkownika
@router.get("/exercises", response_model=List[Exercise])
def get_exercises(user_id: int, db: Session = Depends(get_db)):
    # Sprawdzamy, czy użytkownik istnieje
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="User not found")
    return db.query(ExerciseModel).filter(ExerciseModel.user_id == user_id).all()

# Pobranie planu na tydzień dla użytkownika z wyborem wersji
@router.get("/plan/week/{week_number}", response_model=List[WeekPlan])
def get_week_plan(user_id: int, week_number: int, plan_version: str = "A", db: Session = Depends(get_db)):
    if week_number not in range(1, 7):
        raise HTTPException(status_code=400, detail="Week number must be 1-6")
    
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="User not found")
    
    plans = (
        db.query(WeekPlanModel)
        .options(joinedload(WeekPlanModel.sets))
        .join(ExerciseModel)
        .filter(WeekPlanModel.week_number == week_number, ExerciseModel.user_id == user_id)
        .all()
    )
    
    if not plans:
        plans = generate_week_plan(user_id, week_number, db, plan_version)

    return plans

# Inicjalizacja ćwiczeń dla użytkownika
@router.post("/exercises", response_model=List[Exercise])
def initialize_exercises(user_id: int, exercises: List[ExerciseCreate], db: Session = Depends(get_db)):
    if not db.query(UserModel).filter(UserModel.id == user_id).first():
        raise HTTPException(status_code=404, detail="User not found")
    
    mandatory_exercises = {"squats", "dead_lift", "bench_press"}
    existing_exercises = {ex.name: ex for ex in db.query(ExerciseModel).filter(ExerciseModel.user_id == user_id).all()}
    requested_exercises = {ex.name for ex in exercises}
    
    if not existing_exercises and not mandatory_exercises.issubset(requested_exercises):
        raise HTTPException(
            status_code=400,
            detail="Must provide squats, dead_lift, and bench_press when initializing for the first time"
        )
    
    db_exercises = []
    for ex in exercises:
        if ex.name in existing_exercises:
            continue
        db_ex = ExerciseModel(name=ex.name, one_rep_max=ex.one_rep_max, user_id=user_id)
        db.add(db_ex)
        db_exercises.append(db_ex)
    
    db.commit()
    for ex in db_exercises:
        db.refresh(ex)
    return db_exercises

# Aktualizacja 1RM ćwiczenia
@router.patch("/exercises/{exercise_id}")
def update_exercise(user_id: int, exercise_id: int, updated_data: ExerciseCreate, db: Session = Depends(get_db)):
    exercise = db.query(ExerciseModel).filter(ExerciseModel.id == exercise_id, ExerciseModel.user_id == user_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found or not owned by user")

    exercise.one_rep_max = updated_data.one_rep_max
    exercise.progress_weight = 0.0

    sets = (
        db.query(SetModel)
        .join(WeekPlanModel)
        .filter(WeekPlanModel.exercise_id == exercise_id)
        .all()
    )

    for s in sets:
        s.weight = (exercise.one_rep_max * (s.percentage / 100)) + exercise.progress_weight

    db.commit()
    db.refresh(exercise)
    return {"message": "Exercise updated", "id": exercise.id, "one_rep_max": exercise.one_rep_max}

# Usuwanie ćwiczenia
@router.delete("/exercises/{exercise_id}")
def delete_exercise(user_id: int, exercise_id: int, db: Session = Depends(get_db)):
    exercise = db.query(ExerciseModel).filter(ExerciseModel.id == exercise_id, ExerciseModel.user_id == user_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found or not owned by user")

    protected_exercises = {"squats", "dead_lift", "bench_press"}
    if exercise.name in protected_exercises:
        raise HTTPException(status_code=403, detail=f"Cannot delete {exercise.name}")

    db.query(SetModel).filter(SetModel.week_plan_id.in_(
        db.query(WeekPlanModel.id).filter(WeekPlanModel.exercise_id == exercise_id)
    )).delete(synchronize_session=False)
    db.query(WeekPlanModel).filter(WeekPlanModel.exercise_id == exercise_id).delete(synchronize_session=False)
    db.delete(exercise)
    db.commit()
    return {"message": f"Exercise {exercise.name} deleted successfully"}

# Zapisanie wyniku AMRAP
@router.post("/plan/week/{week_number}/amrap")
def record_amrap(user_id: int, week_number: int, result: AmrapResult, db: Session = Depends(get_db)):
    db_set = (
        db.query(SetModel)
        .join(WeekPlanModel)
        .join(ExerciseModel)
        .filter(SetModel.id == result.set_id, ExerciseModel.user_id == user_id)
        .first()
    )
    if not db_set or not db_set.is_amrap:
        raise HTTPException(status_code=404, detail="Set not found or not AMRAP or not owned by user")

    week_plan = db.query(WeekPlanModel).filter(WeekPlanModel.id == db_set.week_plan_id).first()
    exercise = db.query(ExerciseModel).filter(ExerciseModel.id == week_plan.exercise_id).first()

    if result.reps_performed >= db_set.reps * 2:
        increment = 2.5 if exercise.name == "bench_press" else 5.0
        exercise.progress_weight += increment
        db.commit()
        db.refresh(exercise)

        future_sets = (
            db.query(SetModel)
            .join(WeekPlanModel)
            .filter(WeekPlanModel.exercise_id == exercise.id, WeekPlanModel.week_number > week_plan.week_number)
            .all()
        )
        for s in future_sets:
            s.weight = (exercise.one_rep_max * (s.percentage / 100)) + exercise.progress_weight
        db.commit()

    return {"message": "AMRAP recorded", "progress_weight": exercise.progress_weight}

# Funkcja pomocnicza do generowania planu z wyborem wersji
def generate_week_plan(user_id: int, week_number: int, db: Session, plan_version: str = "A") -> List[WeekPlanModel]:
    exercises = db.query(ExerciseModel).filter(ExerciseModel.user_id == user_id).all()
    plans = []

    # Definicja Planu A (obecny)
    week_plans_a = {
        1: {
            "squats": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "dead_lift": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "bench_press": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)]
        },
        2: {
            "squats": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "dead_lift": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "bench_press": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)]
        },
        3: {
            "squats": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "dead_lift": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "bench_press": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)]
        },
        4: {
            "squats": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "dead_lift": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "bench_press": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)]
        },
        5: {
            "squats": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "dead_lift": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "bench_press": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)]
        },
        6: {
            "squats": [(5, 50, False), (4, 60, False), (3, 70, False), (2, 80, False), (1, 90, False), (1, 100, False)],
            "dead_lift": [(5, 50, False), (4, 60, False), (3, 70, False), (2, 80, False), (1, 90, False), (1, 100, False)],
            "bench_press": [(5, 50, False), (4, 60, False), (3, 70, False), (2, 80, False), (1, 90, False), (1, 100, False)]
        }
    }

    # Definicja Planu B (zmodyfikowany)
    week_plans_b = {
        1: {
            "squats": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "dead_lift": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "bench_press": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)]
        },
        2: {
            "squats": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "dead_lift": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "bench_press": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)]
        },
        3: {
            "squats": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "dead_lift": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "bench_press": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)]
        },
        4: {
            "squats": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "dead_lift": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "bench_press": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)]
        },
        5: {
            "squats": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "dead_lift": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "bench_press": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)]
        },
        6: {
            "squats": [(5, 60, False), (4, 70, False), (3, 80, False), (2, 90, True), (1, 100, False)],
            "dead_lift": [(5, 60, False), (4, 70, False), (3, 80, False), (2, 90, True), (1, 100, False)],
            "bench_press": [(5, 60, False), (4, 70, False), (3, 80, False), (2, 90, True), (1, 100, False)]
        }
    }

    week_plans = week_plans_a if plan_version == "A" else week_plans_b

    for exercise in exercises:
        if week_number not in week_plans or exercise.name not in week_plans[week_number]:
            continue
        
        plan = WeekPlanModel(week_number=week_number, exercise_id=exercise.id)
        db.add(plan)
        db.flush()
        
        for reps, percentage, is_amrap in week_plans[week_number][exercise.name]:
            weight = (exercise.one_rep_max * (percentage / 100)) + exercise.progress_weight
            db_set = SetModel(week_plan_id=plan.id, reps=reps, percentage=percentage, is_amrap=is_amrap, weight=weight)
            db.add(db_set)
        plans.append(plan)
    
    db.commit()
    return plans

@router.get("/compare-plans", response_model=Dict[str, Any])
def compare_training_plans(db: Session = Depends(get_db)):
    """
    Porównuje plany treningowe A i B, pokazując różnice w układzie ćwiczeń
    
    Returns:
        Słownik z opisem obu planów treningowych
    """
    # Definicja Planu A
    week_plans_a = {
        1: {
            "squats": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "dead_lift": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "bench_press": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)]
        },
        2: {
            "squats": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "dead_lift": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "bench_press": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)]
        },
        3: {
            "squats": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "dead_lift": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "bench_press": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)]
        },
        4: {
            "squats": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "dead_lift": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)],
            "bench_press": [(6, 65, False), (4, 75, False), (2, 85, False), (2, 90, False), (2, 90, True), (4, 75, False)]
        },
        5: {
            "squats": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "dead_lift": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "bench_press": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)]
        },
        6: {
            "squats": [(5, 50, False), (4, 60, False), (3, 70, False), (2, 80, False), (1, 90, False), (1, 100, False)],
            "dead_lift": [(5, 50, False), (4, 60, False), (3, 70, False), (2, 80, False), (1, 90, False), (1, 100, False)],
            "bench_press": [(5, 50, False), (4, 60, False), (3, 70, False), (2, 80, False), (1, 90, False), (1, 100, False)]
        }
    }

    # Definicja Planu B
    week_plans_b = {
        1: {
            "squats": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "dead_lift": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "bench_press": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)]
        },
        2: {
            "squats": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "dead_lift": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "bench_press": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)]
        },
        3: {
            "squats": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "dead_lift": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)],
            "bench_press": [(6, 62.5, False), (6, 70, False), (6, 70, False), (6, 70, True)]
        },
        4: {
            "squats": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "dead_lift": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)],
            "bench_press": [(4, 70, False), (4, 75, False), (4, 80, False), (4, 80, False), (4, 80, True)]
        },
        5: {
            "squats": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "dead_lift": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)],
            "bench_press": [(4, 50, False), (3, 65, False), (2, 80, False), (1, 90, False)]
        },
        6: {
            "squats": [(5, 60, False), (4, 70, False), (3, 80, False), (2, 90, True), (1, 100, False)],
            "dead_lift": [(5, 60, False), (4, 70, False), (3, 80, False), (2, 90, True), (1, 100, False)],
            "bench_press": [(5, 60, False), (4, 70, False), (3, 80, False), (2, 90, True), (1, 100, False)]
        }
    }
    
    # Opis różnic między planami
    differences = {
        "plan_a": {
            "description": "Plan A (klasyczny) - różnicuje treningi dla każdego ćwiczenia w ciągu tygodni 1-3 (rotacja 6/4/2, 4/6/6, 5/6/4)",
            "characteristics": [
                "Tydzień 1-3: Każde ćwiczenie ma inny schemat w różnych tygodniach",
                "Tydzień 4: Wszystkie ćwiczenia wykonywane w schemacie 6/4/2 z AMRAP",
                "Tydzień 5: Deload - lżejsze obciążenia dla regeneracji",
                "Tydzień 6: Test maksymalnego ciężaru (do 100% 1RM)"
            ]
        },
        "plan_b": {
            "description": "Plan B (zmodyfikowany) - prostszy, z powtarzającym się schematem 6/4/6/4 w tygodniach 1-4",
            "characteristics": [
                "Tydzień 1 i 3: Wszystkie ćwiczenia w schemacie 6 powtórzeń",
                "Tydzień 2 i 4: Wszystkie ćwiczenia w schemacie 4 powtórzeń",
                "Tydzień 5: Deload - lżejsze obciążenia dla regeneracji",
                "Tydzień 6: Test maksymalnego ciężaru z AMRAP na przedostatnim zestawie"
            ]
        },
        "key_differences": [
            "Plan A ma bardziej zróżnicowany układ treningów w tygodniach 1-3",
            "Plan B ma prostszą, bardziej powtarzalną strukturę (6/4/6/4)",
            "W Planie B, AMRAP występuje również w tygodniu 6 przed ostatnim obciążeniem"
        ]
    }
    
    # Tworzenie czytelnej reprezentacji planów
    plan_a_readable = {}
    plan_b_readable = {}
    
    for week in range(1, 7):
        plan_a_readable[f"week_{week}"] = {}
        plan_b_readable[f"week_{week}"] = {}
        
        for exercise in ["squats", "dead_lift", "bench_press"]:
            plan_a_readable[f"week_{week}"][exercise] = [
                {"reps": r, "percentage": p, "is_amrap": a} 
                for r, p, a in week_plans_a[week][exercise]
            ]
            plan_b_readable[f"week_{week}"][exercise] = [
                {"reps": r, "percentage": p, "is_amrap": a} 
                for r, p, a in week_plans_b[week][exercise]
            ]
    
    return {
        "differences": differences,
        "plan_a": plan_a_readable,
        "plan_b": plan_b_readable
    }
    
    # router.add_api_route("/compare-plans", compare_plans, methods=["GET"], response_model=dict)
    