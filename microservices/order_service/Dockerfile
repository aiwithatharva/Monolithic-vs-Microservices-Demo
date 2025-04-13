FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5003
ENV FLASK_APP=order_service.py
# Service discovery happens via Kubernetes DNS, no need for explicit URLs here
CMD ["gunicorn", "--bind", "0.0.0.0:5003", "--workers", "2", "--log-level", "info", "order_service:app"]