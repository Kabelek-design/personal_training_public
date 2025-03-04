"""Create initial tables for exercises, sets, and week_plans

Revision ID: 1b032662e6d1
Revises: 
Create Date: 2025-02-24 13:50:16.649652

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '1b032662e6d1'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Tworzenie tabeli users
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('nickname', sa.String(length=255), unique=True, nullable=False),
        sa.Column('age', sa.Integer(), nullable=False),
        sa.Column('height', sa.Float(), nullable=False),
        sa.Column('weight', sa.Float(), nullable=False),
        sa.Column('gender', sa.String(length=1), nullable=False),
        sa.Column('weight_goal', sa.Float(), nullable=True),
        sa.Column('plan_version', sa.String(length=1), nullable=False, server_default='A')  # Dodana kolumna z server_default
    )

    # Tworzenie tabeli exercises z relacją do users
    op.create_table(
        'exercises',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('one_rep_max', sa.Float(), nullable=False, default=100.0),
        sa.Column('progress_weight', sa.Float(), nullable=False, default=0.0),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False)
    )

    # Dodanie domyślnego użytkownika z poprawną wartością 'A' w plan_version
    op.execute("""
        INSERT INTO users (nickname, age, height, weight, gender, weight_goal, plan_version) VALUES
        ('test_user', 100, 100.0, 100, 'M', 100, 'A')
    """)

    # Dodanie domyślnych ćwiczeń dla testowego użytkownika (user_id=1)
    op.execute("""
        INSERT INTO exercises (name, one_rep_max, progress_weight, user_id) VALUES
        ('squats', 100.0, 0.0, 1),
        ('dead_lift', 100.0, 0.0, 1),
        ('bench_press', 100.0, 0.0, 1)
    """)

def downgrade():
    op.drop_table('exercises')
    op.drop_table('users')