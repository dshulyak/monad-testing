FROM ubuntu:25.04

WORKDIR /app

COPY latency /app/latency

RUN chmod +x /app/latency

ENTRYPOINT ["/app/latency"]
