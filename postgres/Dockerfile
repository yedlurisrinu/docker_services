FROM postgres:16

# Install required tools once at build time
RUN apt-get update && \
    apt-get install -y \
      --no-install-recommends \
      curl \
    && rm -rf /var/lib/apt/lists/*

# Copy startup script
COPY start-postgres.sh /start-postgres.sh
RUN chmod +x /start-postgres.sh