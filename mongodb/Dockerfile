FROM mongo:8.0

# curl and perl may already be present, add jq for cleaner JSON parsing
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl perl libjson-perl && \
    rm -rf /var/lib/apt/lists/*

COPY start-mongodb.sh /start-mongodb.sh
RUN chmod +x /start-mongodb.sh