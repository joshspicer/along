.PHONY: help server-test server-check integration-test mobile-check mobile-test docker-build compose-up compose-down validate

GO_IMAGE ?= golang:1.26.5-alpine
FLUTTER_IMAGE ?= ghcr.io/cirruslabs/flutter:3.44.6

help:
	@printf '%s\n' \
	  'server-test       Run Go unit tests in the pinned container' \
	  'server-check      Run gofmt, vet, and tests' \
	  'integration-test  Run PostgreSQL integration tests' \
	  'mobile-check      Format and analyze Flutter code with FVM' \
	  'mobile-test       Run Flutter tests with FVM' \
	  'docker-build      Build the production server image' \
	  'compose-up        Start the local stack' \
	  'compose-down      Stop the local stack' \
	  'validate          Run server and mobile checks'

server-test:
	docker run --rm -v "$(CURDIR)/server:/src" -w /src $(GO_IMAGE) go test ./...

server-check:
	./scripts/check-go.sh

integration-test:
	./scripts/test-integration.sh

mobile-check:
	cd mobile && fvm dart format --output=none --set-exit-if-changed lib test
	cd mobile && fvm flutter analyze --fatal-infos

mobile-test:
	cd mobile && fvm flutter test

docker-build:
	docker build --build-arg GIT_COMMIT="$$(git rev-parse HEAD)" -t along-server:dev ./server

compose-up:
	docker compose up -d --build

compose-down:
	docker compose down --remove-orphans

validate: server-check integration-test mobile-check mobile-test docker-build
