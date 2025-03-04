"""user and weight history

Revision ID: d6fad5a97c75
Revises: 94d14b4d16bc
Create Date: 2025-02-28 00:29:54.730700

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = 'd6fad5a97c75'
down_revision: Union[str, None] = '94d14b4d16bc'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        'weight_history',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('weight', sa.Float(), nullable=False),
        sa.Column('recorded_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False)
    )
    op.create_index(op.f('ix_weight_history_id'), 'weight_history', ['id'], unique=False)

    # Dodanie przykładowego rekordu wagi dla user_id=1


def downgrade():
    op.drop_index(op.f('ix_weight_history_id'), table_name='weight_history')
    op.drop_table('weight_history')
