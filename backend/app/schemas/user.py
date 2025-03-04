from pydantic import BaseModel
from typing import Optional, List
from app.schemas.one_rep_max import Exercise
from datetime import datetime

# Definicja WeightHistory w tym samym pliku
class WeightHistory(BaseModel):
    id: int
    user_id: int
    weight: float
    recorded_at: datetime

    class Config:
        from_attributes = True

class UserBase(BaseModel):
    nickname: str
    age: int
    height: float
    weight: float
    gender: str
    weight_goal: Optional[float] = None

class UserCreate(UserBase):
    plan_version: Optional[str] = "A"  # Dodajemy plan_version z domyślną wartością "A"

class UserUpdate(BaseModel):
    nickname: Optional[str] = None
    age: Optional[int] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    gender: Optional[str] = None
    weight_goal: Optional[float] = None
    plan_version: Optional[str] = None  # Opcjonalne dla aktualizacji

class User(UserBase):
    id: int
    exercises: List[Exercise] = []  # Lista ćwiczeń użytkownika
    weight_history: List[WeightHistory] = []  # Używa lokalnej definicji WeightHistory

    class Config:
        from_attributes = True