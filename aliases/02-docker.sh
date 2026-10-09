#!/usr/bin/env bash

alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlog='docker logs -f'
alias dex='docker exec -it'
alias dst='docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'
alias dprune='docker system prune -f'

alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f'
alias dcb='docker compose build'

dclean() {
  docker container prune -f
  docker image prune -f
  docker volume prune -f
  docker network prune -f
  echo "Stopped containers, dangling images, unused volumes and networks removed."
}

dreset() {
  docker compose down --volumes --remove-orphans 2>/dev/null || docker-compose down --volumes --remove-orphans 2>/dev/null
  docker system prune -a --volumes -f
  echo "Nuclear cleanup complete. All containers, images, volumes removed."
}