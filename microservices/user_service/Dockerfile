FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5001
ENV FLASK_APP=user_service.py
CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "2", "--log-level", "info", "user_service:app"]