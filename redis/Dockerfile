FROM redis:8.6-alpine

# Install required tools once at build time
RUN apk add --no-cache curl bash perl perl-json

# Copy startup script
COPY start-redis.sh /start-redis.sh
RUN chmod +x /start-redis.sh