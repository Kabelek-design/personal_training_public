"""Add week plans and default training data

Revision ID: 94d14b4d16bc
Revises: ef9ad6653045
Create Date: 2025-02-24 21:42:09.344725

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision: str = '94d14b4d16bc'
down_revision: Union[str, None] = 'ef9ad6653045'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    # Wstawienie planów dla tygodni 1-6 dla użytkownika o id=1 (Plan A)
    op.execute("""
        INSERT INTO week_plans (week_number, exercise_id)
        SELECT week, id FROM exercises, 
        (SELECT 1 AS week UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6) AS weeks
        WHERE user_id = 1;
    """)

    # Dane dla tygodni 1-6 dla Planu A
    op.execute("""
        INSERT INTO sets (week_plan_id, reps, percentage, is_amrap, weight)
        SELECT wp.id, s.reps, s.percentage, s.is_amrap, (e.one_rep_max * (s.percentage / 100)) + e.progress_weight
        FROM week_plans wp
        JOIN exercises e ON wp.exercise_id = e.id
        JOIN (
            -- TYDZIEŃ 1
            SELECT 'squats' AS exercise, 6 AS reps, 62.5 AS percentage, FALSE AS is_amrap, 1 AS week UNION ALL
            SELECT 'squats', 6, 70, FALSE, 1 UNION ALL
            SELECT 'squats', 6, 70, FALSE, 1 UNION ALL
            SELECT 'squats', 6, 70, TRUE, 1 UNION ALL
            SELECT 'dead_lift', 4, 70, FALSE, 1 UNION ALL
            SELECT 'dead_lift', 4, 75, FALSE, 1 UNION ALL
            SELECT 'dead_lift', 4, 80, FALSE, 1 UNION ALL
            SELECT 'dead_lift', 4, 80, FALSE, 1 UNION ALL
            SELECT 'dead_lift', 4, 80, TRUE, 1 UNION ALL
            SELECT 'bench_press', 6, 65, FALSE, 1 UNION ALL
            SELECT 'bench_press', 4, 75, FALSE, 1 UNION ALL
            SELECT 'bench_press', 2, 85, FALSE, 1 UNION ALL
            SELECT 'bench_press', 2, 90, FALSE, 1 UNION ALL
            SELECT 'bench_press', 2, 90, TRUE, 1 UNION ALL
            SELECT 'bench_press', 4, 75, FALSE, 1 UNION ALL
            -- TYDZIEŃ 2
            SELECT 'squats', 6, 65, FALSE, 2 UNION ALL
            SELECT 'squats', 4, 75, FALSE, 2 UNION ALL
            SELECT 'squats', 2, 85, FALSE, 2 UNION ALL
            SELECT 'squats', 2, 90, FALSE, 2 UNION ALL
            SELECT 'squats', 2, 90, TRUE, 2 UNION ALL
            SELECT 'squats', 4, 75, FALSE, 2 UNION ALL
            SELECT 'dead_lift', 6, 62.5, FALSE, 2 UNION ALL
            SELECT 'dead_lift', 6, 70, FALSE, 2 UNION ALL
            SELECT 'dead_lift', 6, 70, FALSE, 2 UNION ALL
            SELECT 'dead_lift', 6, 70, TRUE, 2 UNION ALL
            SELECT 'bench_press', 4, 70, FALSE, 2 UNION ALL
            SELECT 'bench_press', 4, 75, FALSE, 2 UNION ALL
            SELECT 'bench_press', 4, 80, FALSE, 2 UNION ALL
            SELECT 'bench_press', 4, 80, FALSE, 2 UNION ALL
            SELECT 'bench_press', 4, 80, TRUE, 2 UNION ALL
            -- TYDZIEŃ 3
            SELECT 'squats', 4, 70, FALSE, 3 UNION ALL
            SELECT 'squats', 4, 75, FALSE, 3 UNION ALL
            SELECT 'squats', 4, 80, FALSE, 3 UNION ALL
            SELECT 'squats', 4, 80, FALSE, 3 UNION ALL
            SELECT 'squats', 4, 80, TRUE, 3 UNION ALL
            SELECT 'dead_lift', 6, 65, FALSE, 3 UNION ALL
            SELECT 'dead_lift', 4, 75, FALSE, 3 UNION ALL
            SELECT 'dead_lift', 2, 85, FALSE, 3 UNION ALL
            SELECT 'dead_lift', 2, 90, FALSE, 3 UNION ALL
            SELECT 'dead_lift', 2, 90, TRUE, 3 UNION ALL
            SELECT 'dead_lift', 4, 75, FALSE, 3 UNION ALL
            SELECT 'bench_press', 6, 62.5, FALSE, 3 UNION ALL
            SELECT 'bench_press', 6, 70, FALSE, 3 UNION ALL
            SELECT 'bench_press', 6, 70, FALSE, 3 UNION ALL
            SELECT 'bench_press', 6, 70, TRUE, 3 UNION ALL
            -- TYDZIEŃ 4
            SELECT 'squats', 6, 65, FALSE, 4 UNION ALL
            SELECT 'squats', 4, 75, FALSE, 4 UNION ALL
            SELECT 'squats', 2, 85, FALSE, 4 UNION ALL
            SELECT 'squats', 2, 90, FALSE, 4 UNION ALL
            SELECT 'squats', 2, 90, TRUE, 4 UNION ALL
            SELECT 'squats', 4, 75, FALSE, 4 UNION ALL
            SELECT 'dead_lift', 6, 65, FALSE, 4 UNION ALL
            SELECT 'dead_lift', 4, 75, FALSE, 4 UNION ALL
            SELECT 'dead_lift', 2, 85, FALSE, 4 UNION ALL
            SELECT 'dead_lift', 2, 90, FALSE, 4 UNION ALL
            SELECT 'dead_lift', 2, 90, TRUE, 4 UNION ALL
            SELECT 'dead_lift', 4, 75, FALSE, 4 UNION ALL
            SELECT 'bench_press', 6, 65, FALSE, 4 UNION ALL
            SELECT 'bench_press', 4, 75, FALSE, 4 UNION ALL
            SELECT 'bench_press', 2, 85, FALSE, 4 UNION ALL
            SELECT 'bench_press', 2, 90, FALSE, 4 UNION ALL
            SELECT 'bench_press', 2, 90, TRUE, 4 UNION ALL
            SELECT 'bench_press', 4, 75, FALSE, 4 UNION ALL
            -- TYDZIEŃ 5 (Deload)
            SELECT 'squats', 4, 50, FALSE, 5 UNION ALL
            SELECT 'squats', 3, 65, FALSE, 5 UNION ALL
            SELECT 'squats', 2, 80, FALSE, 5 UNION ALL
            SELECT 'squats', 1, 90, FALSE, 5 UNION ALL
            SELECT 'dead_lift', 4, 50, FALSE, 5 UNION ALL
            SELECT 'dead_lift', 3, 65, FALSE, 5 UNION ALL
            SELECT 'dead_lift', 2, 80, FALSE, 5 UNION ALL
            SELECT 'dead_lift', 1, 90, FALSE, 5 UNION ALL
            SELECT 'bench_press', 4, 50, FALSE, 5 UNION ALL
            SELECT 'bench_press', 3, 65, FALSE, 5 UNION ALL
            SELECT 'bench_press', 2, 80, FALSE, 5 UNION ALL
            SELECT 'bench_press', 1, 90, FALSE, 5 UNION ALL
            -- TYDZIEŃ 6 (Test max)
            SELECT 'squats', 5, 50, FALSE, 6 UNION ALL
            SELECT 'squats', 4, 60, FALSE, 6 UNION ALL
            SELECT 'squats', 3, 70, FALSE, 6 UNION ALL
            SELECT 'squats', 2, 80, FALSE, 6 UNION ALL
            SELECT 'squats', 1, 90, FALSE, 6 UNION ALL
            SELECT 'squats', 1, 100, FALSE, 6 UNION ALL
            SELECT 'dead_lift', 5, 50, FALSE, 6 UNION ALL
            SELECT 'dead_lift', 4, 60, FALSE, 6 UNION ALL
            SELECT 'dead_lift', 3, 70, FALSE, 6 UNION ALL
            SELECT 'dead_lift', 2, 80, FALSE, 6 UNION ALL
            SELECT 'dead_lift', 1, 90, FALSE, 6 UNION ALL
            SELECT 'dead_lift', 1, 100, FALSE, 6 UNION ALL
            SELECT 'bench_press', 5, 50, FALSE, 6 UNION ALL
            SELECT 'bench_press', 4, 60, FALSE, 6 UNION ALL
            SELECT 'bench_press', 3, 70, FALSE, 6 UNION ALL
            SELECT 'bench_press', 2, 80, FALSE, 6 UNION ALL
            SELECT 'bench_press', 1, 90, FALSE, 6 UNION ALL
            SELECT 'bench_press', 1, 100, FALSE, 6
        ) s ON e.name = s.exercise AND wp.week_number = s.week;
    """)

def downgrade():
    op.execute("DELETE FROM sets WHERE week_plan_id IN (SELECT id FROM week_plans WHERE exercise_id IN (SELECT id FROM exercises WHERE user_id = 1))")
    op.execute("DELETE FROM week_plans WHERE exercise_id IN (SELECT id FROM exercises WHERE user_id = 1)")