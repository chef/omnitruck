#!/bin/bash
# filepath: omnitruck/dev/start-dev.sh

# Change to the dev directory
cd "$(dirname "$0")"

# Build and start containers
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 5

# Execute the poller to populate Redis cache
echo "Running poller to populate Redis cache..."
docker-compose exec omnitruck bundle exec ./poller -e development

echo -e "\n==============================================="
echo "Development environment is ready!"
echo "Omnitruck app is running at: http://localhost:9393"
echo "Redis is running at: localhost:6379"
echo -e "===============================================\n"

# Show logs
docker-compose logs -f