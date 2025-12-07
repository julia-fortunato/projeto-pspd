locust -f locustfile.py \
  --host http://localhost:8080 \
  --headless \
  -u 200 \
  -r 5 \
  -t 5m \
  --csv=baseline_simple
