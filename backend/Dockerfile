# Use Python 3.11 slim image
FROM python:3.11-slim

# Install build dependencies for liboqs
RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    libssl-dev \
    python3-dev \
    build-essential \
    git \
    astyle \
    && rm -rf /var/lib/apt/lists/*

# Clone and build liboqs from source
RUN git clone --branch main \
    https://github.com/open-quantum-safe/liboqs.git \
    && cmake -S liboqs -B liboqs/build \
    -DOQS_DIST_BUILD=ON \
    -DBUILD_SHARED_LIBS=ON \
    && cmake --build liboqs/build \
    --parallel 4 \
    && cmake --install liboqs/build

# Install liboqs-python
RUN pip install liboqs-python

# Set working directory
WORKDIR /app

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY . .

# Start server
CMD ["uvicorn", "main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000"]
