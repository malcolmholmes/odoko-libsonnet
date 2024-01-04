FROM golang:1.21.5-alpine3.19 as builder

ENV GO111MODULE=on

WORKDIR /app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o backup ./

FROM alpine:3.19
RUN apk add mysql-client postgresql-client
COPY --from=builder /app/backup /app/
ENTRYPOINT ["/app/backup"]
