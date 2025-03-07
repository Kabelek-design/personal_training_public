# backend/app/models/training_schedule.py
from sqlalchemy import Column, ForeignKey, Integer, Float, Date, String, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db import Base

class TrainingPlanSchedule(Base):
    __tablename__ = "training_plan_schedules"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(255), nullable=False)
    scheduled_date = Column(Date, nullable=False)
    notes = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    user = relationship("User", back_populates="training_schedules")
    exercises = relationship("ExerciseSchedule", back_populates="training_plan", cascade="all, delete-orphan")

class ExerciseSchedule(Base):
    __tablename__ = "exercise_schedules"

    id = Column(Integer, primary_key=True, index=True)
    training_plan_id = Column(Integer, ForeignKey("training_plan_schedules.id"), nullable=False)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)
    sets = Column(Integer, nullable=False)
    reps = Column(Integer, nullable=False)
    weight = Column(Float, nullable=False)
    rest_time = Column(Integer, nullable=True)  # czas odpoczynku w sekundach
    notes = Column(String(255), nullable=True)
    
    training_plan = relationship("TrainingPlanSchedule", back_populates="exercises")
    exercise = relationship("Exercise")