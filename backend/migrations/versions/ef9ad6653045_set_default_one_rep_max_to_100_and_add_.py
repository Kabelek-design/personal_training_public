"""Set default one_rep_max to 100 and add missing tables

Revision ID: ef9ad6653045
Revises: 1b032662e6d1
Create Date: 2025-02-24 21:39:44.105984

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = 'ef9ad6653045'
down_revision: Union[str, None] = '1b032662e6d1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Tworzenie tabeli week_plans
    op.create_table(
        'week_plans',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('week_number', sa.Integer(), nullable=False),
        sa.Column('exercise_id', sa.Integer(), sa.ForeignKey('exercises.id'), nullable=False)
    )

    # Tworzenie tabeli sets
    op.create_table(
        'sets',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('week_plan_id', sa.Integer(), sa.ForeignKey('week_plans.id'), nullable=False),
        sa.Column('reps', sa.Integer(), nullable=False),
        sa.Column('percentage', sa.Float(), nullable=False),
        sa.Column('is_amrap', sa.Boolean(), nullable=False, default=False),
        sa.Column('weight', sa.Float(), nullable=False)
    )

def downgrade():
    op.drop_table('sets')
    op.drop_table('week_plans')