FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    libssl-dev \
    python3-dev \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 \
    https://github.com/open-quantum-safe/liboqs.git \
    && cmake -S liboqs -B liboqs/build \
    -DOQS_DIST_BUILD=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build liboqs/build \
    --parallel 4 \
    && cmake --install liboqs/build \
    && ldconfig \
    && rm -rf liboqs

RUN git clone --depth 1 \
    https://github.com/open-quantum-safe/liboqs-python.git \
    && cd liboqs-python \
    && pip install . \
    && cd .. \
    && rm -rf liboqs-python

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

EXPOSE 10000

CMD uvicorn main:app \
    --host 0.0.0.0 \
    --port ${PORT:-10000}
