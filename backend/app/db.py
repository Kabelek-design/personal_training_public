from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
# Import wszystkich modeli, aby Base je uwzględnił


# URL bazy danych MySQL
SQLALCHEMY_DATABASE_URL = "mysql+mysqldb://root:fastapi@db:3306/training_db"

# Tworzenie silnika bazy danych
engine = create_engine(SQLALCHEMY_DATABASE_URL, echo=True, pool_pre_ping=True)


# Tworzenie sesji
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Baza dla modeli
Base = declarative_base()



def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()