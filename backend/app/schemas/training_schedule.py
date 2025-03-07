# backend/app/schemas/training_schedule.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime

class ExerciseScheduleBase(BaseModel):
    exercise_id: int
    sets: int
    reps: int
    weight: float
    rest_time: Optional[int] = None
    notes: Optional[str] = None

class ExerciseScheduleCreate(ExerciseScheduleBase):
    pass

class ExerciseSchedule(ExerciseScheduleBase):
    id: int
    training_plan_id: int

    class Config:
        from_attributes = True

class TrainingPlanScheduleBase(BaseModel):
    name: str
    scheduled_date: date
    notes: Optional[str] = None

class TrainingPlanScheduleCreate(TrainingPlanScheduleBase):
    exercises: List[ExerciseScheduleCreate]

class TrainingPlanSchedule(TrainingPlanScheduleBase):
    id: int
    user_id: int
    created_at: datetime
    exercises: List[ExerciseSchedule]

    class Config:
        from_attributes = True

# Schemat dla aktualizacji planu treningowego
class TrainingPlanScheduleUpdate(BaseModel):
    name: Optional[str] = None
    scheduled_date: Optional[date] = None
    notes: Optional[str] = None

# Schemat dla aktualizacji ćwiczenia w planie
class ExerciseScheduleUpdate(BaseModel):
    sets: Optional[int] = None
    reps: Optional[int] = None
    weight: Optional[float] = None
    rest_time: Optional[int] = None
    notes: Optional[str] = None