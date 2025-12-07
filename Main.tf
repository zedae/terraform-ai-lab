terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# ==================================================
# TODO 1 : Créer un réseau Docker
# ==================================================

resource "docker_network" "ia_network" {
  name   = "ia-network"
  driver = "bridge"
}

# ==================================================
# TODO 2 : Créer les 2 volumes persistants
# ==================================================

resource "docker_volume" "ollama_storage" {
  name = "ollama_storage"
}

resource "docker_volume" "webui_storage" {
  name = "webui_storage"
}

# ==================================================
# TODO 3 : Conteneur Ollama
# ==================================================

# 1. On déclare d'abord l'image pour que Terraform la pull
resource "docker_image" "ollama" {
  name         = "ollama/ollama:latest"
  keep_locally = false
}

resource "docker_container" "ollama" {
  name    = "ollama"
  image   = docker_image.ollama.image_id
  restart = "always"

  # Gestion du réseau
  networks_advanced {
    name = docker_network.ia_network.name
  }

  # Mapping des ports (Host <- Container)
  ports {
    internal = 11435
    external = 11435
  }

  # Montage du volume
  volumes {
    volume_name    = docker_volume.ollama_storage.name
    container_path = "/root/.ollama"
  }
}

# ==================================================
# TODO 4 : Conteneur Open WebUI
# ==================================================

# 1. On déclare l'image
resource "docker_image" "webui" {
  name         = "ghcr.io/open-webui/open-webui:main"
  keep_locally = false
}

resource "docker_container" "webui" {
  name  = "open-webui"
  image = docker_image.webui.image_id

  # Dépendance explicite : on attend que Ollama soit créé
  depends_on = [docker_container.ollama]

  networks_advanced {
    name = docker_network.ia_network.name
  }

  # Attention : Port externe 3000 -> Interne 8080
  ports {
    internal = 8080
    external = 3000
  }

  # Variables d'environnement
  env = [
    "OLLAMA_BASE_URL=http://ollama:11435"
  ]

  # Montage du volume
  volumes {
    volume_name    = docker_volume.webui_storage.name
    container_path = "/app/backend/data"
  }
}