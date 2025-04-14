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
    password: str  # Dodane pole hasła
    plan_version: Optional[str] = "A"

class UserLogin(BaseModel):
    nickname: str
    password: str

class UserUpdate(BaseModel):
    nickname: Optional[str] = None
    password: Optional[str] = None  # Dodane opcjonalne pole hasła
    age: Optional[int] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    gender: Optional[str] = None
    weight_goal: Optional[float] = None
    plan_version: Optional[str] = None

class User(UserBase):
    id: int
    exercises: List[Exercise] = []
    weight_history: List[WeightHistory] = []

    class Config:
        from_attributes = True
        
class PlanVersionChange(BaseModel):
    plan_version: str

class LoginResponse(BaseModel):
    id: int
    nickname: str
    token: Optional[str] = None  # Opcjonalnie, jeśli planujesz użyć tokenów