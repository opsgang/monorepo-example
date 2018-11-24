##
# Build stage
##

FROM golang:1.11-alpine as builder

WORKDIR /go/src/app
COPY . .

RUN go build src/hello-world.go

##
# Production stage
##

FROM alpine:3.8

LABEL \
    version="$APP_VERSION" \
    os="Linux" \
    git_branch=$GIT_BRANCH \
    arch="amd64"

WORKDIR /go/src/app
COPY --from=builder /code/go/src/app/hello-world .

CMD ["./hello-world"]
