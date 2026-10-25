FROM python:3.13.7-slim-bookworm AS builder
WORKDIR /build
COPY app.py .
RUN python -m py_compile app.py && cp __pycache__/app.*.pyc app.pyc

FROM python:3.13.7-slim-bookworm AS runtime
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_MESSAGE="Lab 2"
WORKDIR /app
RUN groupadd -g 10001 app && useradd -u 10001 -g app -M -s /usr/sbin/nologin app
COPY --from=builder /build/app.pyc .
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)"]
ENTRYPOINT ["python", "/app/app.pyc"]
