#!/bin/bash

docker load -i "dist/img.tar"
find demo -type f -name 'img.tar' | while read -r tar; do
  docker load -i "$tar"
done

image_list=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^ghcr.io/second-state")

for image in $image_list; do
  docker push $image
done
