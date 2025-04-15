"""password

Revision ID: 84b8a9df9168
Revises: 1c2f8acad1ac
Create Date: 2025-04-14 10:25:55.211799

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '84b8a9df9168'
down_revision: Union[str, None] = '1c2f8acad1ac'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Najpierw sprawdź, czy kolumna password_hash już istnieje 
    # i dodaj ją, jeśli nie istnieje
    try:
        op.add_column('users', sa.Column('password_hash', sa.String(255), nullable=True))
    except Exception as e:
        print(f"Kolumna może już istnieć: {e}")
    
    # Ustaw domyślne hasło dla istniejących rekordów
    default_hash = "$2b$12$UMVRnq/xDz9N7ZngAUWvxO1xu9kk3Jh80.HJRb3qG8WgBmGcvxbpO"  # Zahaszowane "password"
    op.execute(f"UPDATE users SET password_hash = '{default_hash}' WHERE password_hash IS NULL")
    
    # Zmień kolumnę na not nullable
    op.alter_column('users', 'password_hash',
               existing_type=mysql.VARCHAR(length=255),
               nullable=False)

def downgrade() -> None:
    # Najpierw zmień kolumnę na nullable
    op.alter_column('users', 'password_hash',
               existing_type=mysql.VARCHAR(length=255),
               nullable=True)
    
    # Opcjonalnie możesz również usunąć kolumnę
    # op.drop_column('users', 'password_hash')
