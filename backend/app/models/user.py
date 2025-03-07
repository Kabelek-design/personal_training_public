# backend/app/models/user.py
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.orm import relationship
from app.db import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    nickname = Column(String(255), unique=True, index=True, nullable=False)
    age = Column(Integer, nullable=False)
    height = Column(Float, nullable=False)
    weight = Column(Float, nullable=False)
    gender = Column(String(1), nullable=False)
    weight_goal = Column(Float, nullable=True)
    plan_version = Column(String(1), nullable=False, default="A")
    
    exercises = relationship("Exercise", back_populates="user", cascade="all, delete-orphan")
    weight_history = relationship("WeightHistory", back_populates="user", cascade="all, delete-orphan")
    training_schedules = relationship("TrainingPlanSchedule", back_populates="user", cascade="all, delete-orphan")