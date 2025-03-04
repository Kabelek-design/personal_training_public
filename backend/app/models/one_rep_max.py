from sqlalchemy import VARCHAR, Column, Integer, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.db import Base
from sqlalchemy.sql import func
from sqlalchemy import DateTime

class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(VARCHAR(255), nullable=False, index=True)
    one_rep_max = Column(Float, nullable=False, default=100.0)
    progress_weight = Column(Float, nullable=False, default=0.0)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    user = relationship("User", back_populates="exercises")
    week_plans = relationship("WeekPlan", back_populates="exercise", cascade="all, delete-orphan")

class WeekPlan(Base):
    __tablename__ = "week_plans"

    id = Column(Integer, primary_key=True, index=True)
    week_number = Column(Integer, nullable=False)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)

    exercise = relationship("Exercise", back_populates="week_plans")
    sets = relationship("Set", back_populates="week_plan", lazy="joined", cascade="all, delete-orphan")

class Set(Base):
    __tablename__ = "sets"

    id = Column(Integer, primary_key=True, index=True)
    week_plan_id = Column(Integer, ForeignKey("week_plans.id"), nullable=False)
    reps = Column(Integer, nullable=False)
    percentage = Column(Float, nullable=False)
    is_amrap = Column(Boolean, nullable=False, default=False)
    weight = Column(Float, nullable=False)

    week_plan = relationship("WeekPlan", back_populates="sets")
