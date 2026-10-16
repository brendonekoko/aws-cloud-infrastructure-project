#!/bin/bash
set -e
aws s3api get-object \
  --bucket yvettes-realty-639283100969-us-east-2 \
  --key website/yvettes-website.tar.gz \
  /tmp/yvettes-website.tar.gz

mkdir -p /var/www/html
tar -xzf /tmp/yvettes-website.tar.gz -C /var/www/html
systemctl restart httpd
