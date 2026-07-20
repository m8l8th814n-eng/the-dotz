#!/usr/bin/env bash
for v in 12 10 15 20 15 10; do
  hypr-set.sh decoration:rounding $v
  sleep 0.05
done
