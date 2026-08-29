# Start from a small, official Python image — not the full Python image,
# which is much larger and includes tools we don't need for a simple app
FROM python:3.12-slim

# Set the working directory inside the container — everything from here
# happens relative to /app
WORKDIR /app

# Copy just the requirements file first (not the whole app yet) — this is
# a deliberate ordering trick: Docker caches each step, so if only your
# app code changes later (not your dependencies), Docker skips reinstalling
# everything and rebuilds much faster
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the actual application code
COPY app.py .

# Document which port the app listens on (informational — doesn't actually
# open the port, that happens later when we run the container)
EXPOSE 5000

# The command that runs when the container starts
CMD ["python", "app.py"]
