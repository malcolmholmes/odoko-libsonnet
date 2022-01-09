FROM golang:1.17.0-alpine3.14 as go-builder
WORKDIR /app
ADD * /app/
RUN CGO_ENABLED=0 go build -o webhook

FROM klakegg/hugo:0.83.1-ext-alpine
WORKDIR /app
COPY --from=go-builder /app/webhook /usr/bin/webhook
ENTRYPOINT ["webhook"]
