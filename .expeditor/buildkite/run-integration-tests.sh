#!/bin/bash
set -eou pipefail

echo "=========================================="
echo "Starting Omnitruck Integration Tests"
echo "=========================================="
echo ""

COMPOSE_FILE=".expeditor/docker-compose.ci.yml"

# Step 1: Start services
echo "Step 1: Starting Docker services..."
docker-compose -f "$COMPOSE_FILE" up -d

# Step 2: Wait for services to be healthy
echo "Step 2: Waiting for services to be ready..."
MAX_WAIT=120
WAITED=0

# Wait for Redis to be healthy
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker-compose -f "$COMPOSE_FILE" ps redis | grep -q "healthy"; then
        echo "✅ Redis is healthy"
        break
    fi
    echo "Waiting for Redis... ($WAITED/$MAX_WAIT seconds)"
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "❌ Redis failed to become healthy within $MAX_WAIT seconds"
    docker-compose -f "$COMPOSE_FILE" logs
    docker-compose -f "$COMPOSE_FILE" down -v
    exit 1
fi

# Wait for Omnitruck to respond
echo "Waiting for Omnitruck service to be ready..."
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf http://localhost:8080/products > /dev/null 2>&1; then
        echo "✅ Omnitruck is responding"
        break
    fi
    echo "Waiting for Omnitruck... ($WAITED/$MAX_WAIT seconds)"
    sleep 3
    WAITED=$((WAITED + 3))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "❌ Omnitruck failed to respond within $MAX_WAIT seconds"
    echo "Container logs:"
    docker-compose -f "$COMPOSE_FILE" logs omnitruck
    docker-compose -f "$COMPOSE_FILE" down -v
    exit 1
fi

# Step 3: Show service status
echo ""
echo "Step 3: Service status:"
docker-compose -f "$COMPOSE_FILE" ps
echo ""

# Step 4: Populate Redis cache
echo "Step 4: Populating Redis cache (may take 2-3 minutes)..."
if timeout 180 docker-compose -f "$COMPOSE_FILE" exec -T omnitruck bundle exec ./poller 2>&1 | head -20; then
    echo "✅ Redis cache populated"
else
    echo "⚠️  Warning: Poller timed out or failed. Continuing with tests (some data may be missing)..."
    # Tests can still run without full cache, they'll just have less data
fi
echo ""

# Step 5: Run RSpec tests
echo "Step 5: Running RSpec test suite..."
if docker-compose -f "$COMPOSE_FILE" exec -T omnitruck bundle exec rspec --format documentation; then
    echo "✅ RSpec tests passed"
else
    echo "❌ RSpec tests failed"
    docker-compose -f "$COMPOSE_FILE" logs
    docker-compose -f "$COMPOSE_FILE" down -v
    exit 1
fi
echo ""

# Step 6: Run smoke tests
echo "Step 6: Running smoke tests..."
if ./.expeditor/buildkite/test-endpoints.sh http://localhost:8080; then
    echo "✅ Smoke tests passed"
else
    echo "❌ Smoke tests failed"
    docker-compose -f "$COMPOSE_FILE" logs
    docker-compose -f "$COMPOSE_FILE" down -v
    exit 1
fi
echo ""

# Cleanup
echo "Step 7: Cleaning up..."
docker-compose -f "$COMPOSE_FILE" down -v

echo ""
echo "=========================================="
echo "✅ All integration tests passed!"
echo "=========================================="
