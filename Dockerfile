FROM golang:1.23.3-alpine as build

WORKDIR /app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux go build -o foods-api

FROM alpine:3.22.0

WORKDIR /app

ENV PORT=8080

COPY --from=build /app/foods-api .

ENTRYPOINT ["/app/foods-api"]