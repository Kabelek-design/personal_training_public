from pydantic import BaseModel
from typing import Optional, List

# Schemat dla ćwiczenia
class ExerciseBase(BaseModel):
    name: str
    one_rep_max: float

class ExerciseCreate(ExerciseBase):
    pass

class Exercise(ExerciseBase):
    id: int
    progress_weight: Optional[float] = 0.0
    user_id: int  # Dodajemy relację do użytkownika
    week_plans: Optional[List["WeekPlan"]] = []  # Opcjonalna lista planów tygodniowych

    class Config:
        from_attributes = True

# Schemat dla serii w planie
class SetBase(BaseModel):
    reps: int
    percentage: float
    is_amrap: bool = False

class SetCreate(SetBase):
    pass

class Set(SetBase):
    id: int
    weight: Optional[float] = None
    week_plan_id: int  # Relacja do WeekPlan

    class Config:
        from_attributes = True

# Schemat dla planu tygodniowego
class WeekPlanBase(BaseModel):
    week_number: int
    exercise_id: int
    sets: List[SetCreate] = []

class WeekPlanCreate(WeekPlanBase):
    pass

class WeekPlan(WeekPlanBase):
    id: int
    sets: List[Set]  # Pełne obiekty Set po zapisaniu

    class Config:
        from_attributes = True

# Schemat dla wyniku AMRAP
class AmrapResult(BaseModel):
    set_id: int
    reps_performed: int  # ile powtórzeń użytkownik wykonał