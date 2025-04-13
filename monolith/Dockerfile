# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY . .

# Make port 5000 available to the world outside this container
EXPOSE 5000

# Define environment variable (optional, can be overridden)
ENV FLASK_APP=monolith_app.py
# ENV FLASK_ENV=production # Set to production if not using debug/dev

# Run monolith_app.py using Gunicorn when the container launches
# Use gunicorn for a slightly more robust server than flask run
# Use --log-level info to see basic request logs
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--log-level", "info", "monolith_app:app"]