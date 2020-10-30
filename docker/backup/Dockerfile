FROM golang:1.13 as builder

ENV GO111MODULE=on

WORKDIR /app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o backup ./

FROM alpine:3.10
RUN apk add mysql-client
COPY --from=builder /app/backup /app/
ENTRYPOINT ["/app/backup"]
