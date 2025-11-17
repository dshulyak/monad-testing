FROM ubuntu:25.04

WORKDIR /app

COPY latency /app/latency

RUN chmod +x /app/latency

EXPOSE 6060

ENTRYPOINT ["/app/latency"]
