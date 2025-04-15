# backend/app/models/user.py
from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.orm import relationship
from app.db import Base
from passlib.hash import bcrypt

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    nickname = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)  # Dodane pole dla hasła
    age = Column(Integer, nullable=False)
    height = Column(Float, nullable=False)
    weight = Column(Float, nullable=False)
    gender = Column(String(1), nullable=False)
    weight_goal = Column(Float, nullable=True)
    plan_version = Column(String(1), nullable=False, default="A")
    
    exercises = relationship("Exercise", back_populates="user", cascade="all, delete-orphan")
    weight_history = relationship("WeightHistory", back_populates="user", cascade="all, delete-orphan")
    training_schedules = relationship("TrainingPlanSchedule", back_populates="user", cascade="all, delete-orphan")
    
    def verify_password(self, password):
        """Weryfikacja hasła"""
        return bcrypt.verify(password, self.password_hash)
    
    @staticmethod
    def hash_password(password):
        return bcrypt.hash(password)