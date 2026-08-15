FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /agore-server ./cmd/agore-server

FROM alpine:3.20
RUN apk add --no-cache wget \
    && adduser -D -H agore
USER agore
COPY --from=build /agore-server /agore-server
EXPOSE 8081
ENV AGORE_ADDR=:8081
ENTRYPOINT ["/agore-server"]
