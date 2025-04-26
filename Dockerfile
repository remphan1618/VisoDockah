name: Build and Push Docker Image

on:
  push:
    branches:
      - main  # Trigger on pushes to the main branch
  workflow_dispatch:  # Allow manual triggering from the GitHub UI

jobs:
  build-and-push:
    name: Build and Push
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Important for accurate Git SHA and caching

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          driver: docker  # Use the 'docker' driver

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_PASSWORD }}

      - name: Build and push Docker image
        id: build-and-push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/visomasterdockah:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/visomasterdockah:${{ github.sha }}
          cache-from: type=cache,id=visomaster-docker-cache
          cache-to: type=cache,id=visomaster-docker-cache,mode=max
          
      - name: Image digest
        run: echo "Image digest: ${{ steps.build-and-push.outputs.digest }}"

