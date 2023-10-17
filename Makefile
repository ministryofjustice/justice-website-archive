default: launch

IMAGE := ministryofjustice/justice-website-archive

# Start the application
run: env dory
	docker compose up

up_daemon: env dory
	docker compose up -d

env:
	@if [[ ! -f ".env" ]]; then cp .env.example .env; fi

# Bring docker compose down
down:
	docker compose down

# Start the Dory Proxy
dory:
	@chmod +x ./bin/dory-start.sh && ./bin/dory-start.sh

sync:
	@docker compose exec spider s3sync

build:
	bin/build.sh

launch: build dory
	@bin/launch.sh
	@echo "\n Justice spider available here: http://spider.justice.docker/\n"
	@docker compose logs -f spider

image: Dockerfile Makefile build
	docker build -t $(IMAGE) .

# Get inside the spider container
shell:
	docker compose exec spider /bin/bash
