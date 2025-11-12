#!/bin/bash

echo "labeling pods with bucket assignments..."

kubectl label pod latency-0 latency-bucket=bucket-1 --overwrite
kubectl label pod latency-1 latency-bucket=bucket-1 --overwrite

kubectl label pod latency-2 latency-bucket=bucket-2 --overwrite
kubectl label pod latency-3 latency-bucket=bucket-2 --overwrite

kubectl label pod latency-4 latency-bucket=bucket-3 --overwrite
kubectl label pod latency-5 latency-bucket=bucket-3 --overwrite

kubectl label pod latency-6 latency-bucket=bucket-4 --overwrite
kubectl label pod latency-7 latency-bucket=bucket-4 --overwrite

kubectl label pod latency-8 latency-bucket=bucket-5 --overwrite
kubectl label pod latency-9 latency-bucket=bucket-5 --overwrite

echo "bucket labeling complete"
echo ""
echo "bucket assignments:"
echo "  bucket-1: latency-0, latency-1"
echo "  bucket-2: latency-2, latency-3"
echo "  bucket-3: latency-4, latency-5"
echo "  bucket-4: latency-6, latency-7"
echo "  bucket-5: latency-8, latency-9"
