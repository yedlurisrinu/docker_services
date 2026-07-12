LABEL authors="yedlurisrinu"

FROM qdrant/qdrant:latest

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends bash curl perl libjson-perl && \
    rm -rf /var/lib/apt/lists/*

COPY start-qdrant.sh /start-qdrant.sh
RUN chmod +x /start-qdrant.sh

USER 1000