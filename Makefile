.PHONY: start stop down clean logs rebuild status

start:    ## Start container in background
	docker compose up -d

stop:     ## Stop container (preserves volume)
	docker compose stop

down:     ## Remove container (preserves volume)
	docker compose down

clean:    ## Remove container + volume + image (full reset)
	docker compose down -v --rmi local

logs:     ## Follow container logs
	docker compose logs -f

rebuild:  ## Pull latest image and restart
	docker compose pull && docker compose up -d

status:   ## Show container status
	docker compose ps
