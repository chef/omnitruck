#!/bin/bash

cd "$(dirname "$0")"

echo "Stopping containers..."
docker-compose down

echo "Removing bundle cache volume..."
docker volume rm dev_bundle_cache || true

echo "Rebuilding images from scratch..."
docker-compose build --no-cache

echo "Starting containers..."
docker-compose up -d

echo "Containers started. Waiting for services to initialize..."
sleep 5

echo "Checking container logs..."
docker-compose logs