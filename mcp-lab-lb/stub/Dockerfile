# docker_services/mcp-lab-lb/stub/Dockerfile — C0 step 4: image for the two stub MCP replicas.
FROM python:3.12-slim
# Pinned to the thread's SDK version; uvicorn serves the Starlette app the SDK builds.
RUN pip install --no-cache-dir "mcp==2.3.0" "uvicorn==0.54.0"
WORKDIR /app
COPY server.py .
# Run as a non-root user.
RUN useradd --uid 10001 --no-create-home app
USER app
EXPOSE 8000
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]