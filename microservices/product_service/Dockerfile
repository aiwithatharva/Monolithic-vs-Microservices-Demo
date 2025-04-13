FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5002
ENV FLASK_APP=product_service.py
CMD ["gunicorn", "--bind", "0.0.0.0:5002", "--workers", "2", "--log-level", "info", "product_service:app"]