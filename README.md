# docker_services

Central entry point for all Docker infrastructure services.

## Services
| Service | Description |
|---------|-------------|
| [postgres](https://github.com/yedlurisrinu/postgres.git) | PostgreSQL 16 with Vault integration |
| [pypi-server](https://github.com/yedlurisrinu/pypi-server.git) | Private PyPI package server |

## Clone Everything
git clone --recurse-submodules \
  https://github.com/yedlurisrinu/docker_services.git

## Clone Individual Service
git clone https://github.com/yedlurisrinu/postgres.git
git clone https://github.com/yedlurisrinu/pypi-server.git

## Update All Submodules to Latest
git submodule update --remote --merge

## Start All Services
cd postgres && docker compose up -d && cd ..
cd pypi-server && docker compose up -d && cd ..
