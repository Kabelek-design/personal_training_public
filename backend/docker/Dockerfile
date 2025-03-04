FROM python:3.10

# 1. Zainstaluj paczki potrzebne do kompilacji mysqlclient i dockerize
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    wget \
    default-libmysqlclient-dev \
 && rm -rf /var/lib/apt/lists/*

# Pobierz i zainstaluj dockerize
RUN wget https://github.com/jwilder/dockerize/releases/download/v0.6.1/dockerize-linux-amd64-v0.6.1.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-v0.6.1.tar.gz \
    && rm dockerize-linux-amd64-v0.6.1.tar.gz

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

COPY docker/startup.sh /docker/startup.sh
RUN chmod +x /docker/startup.sh
CMD ["/docker/startup.sh"]
