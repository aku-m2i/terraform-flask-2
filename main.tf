terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.27.0"
    }
  }
}

provider "kubernetes" {
  config_path = "C:/Users/Administrateur/.kube/config"
}

# -------------------------
# Variables
# -------------------------
variable "flask_code" {
  type    = string
  default = <<EOT
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return '<h1>Flask V1</h1>'

app.run(host='0.0.0.0', port=8080)
EOT
}

variable "flask_requirements" {
  type    = string
  default = "flask\n"
}

# -------------------------
# ConfigMaps
# -------------------------
resource "kubernetes_config_map" "flask_code" {
  metadata {
    name      = "flask-code"
    namespace = "freakhill-dev"
  }

  data = {
    "app.py" = var.flask_code
  }
}

resource "kubernetes_config_map" "flask_requirements" {
  metadata {
    name      = "flask-requirements"
    namespace = "freakhill-dev"
  }

  data = {
    "requirements.txt" = var.flask_requirements
  }
}

# -------------------------
# Deployment
# -------------------------
resource "kubernetes_deployment" "flask" {
  metadata {
    name      = "flask-app"
    namespace = "freakhill-dev"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "flask-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "flask-app"
        }
      }

      spec {
        container {
          name    = "flask"
          image   = "registry.access.redhat.com/ubi9/python-39"
          command = ["/bin/sh", "-c", "pip install -r /app/requirements.txt && python3 /app/app.py"]

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "code"
            mount_path = "/app/app.py"
            sub_path   = "app.py"
          }

          volume_mount {
            name       = "requirements"
            mount_path = "/app/requirements.txt"
            sub_path   = "requirements.txt"
          }
        }

        volume {
          name = "code"
          config_map {
            name = kubernetes_config_map.flask_code.metadata[0].name
          }
        }

        volume {
          name = "requirements"
          config_map {
            name = kubernetes_config_map.flask_requirements.metadata[0].name
          }
        }
      }
    }
  }
}

# -------------------------
# Service
# -------------------------
resource "kubernetes_service" "flask" {
  metadata {
    name      = "flask-service"
    namespace = "freakhill-dev"
  }

  spec {
    selector = {
      app = "flask-app"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# -------------------------
# Expose via OpenShift route
# -------------------------
resource "null_resource" "expose_flask_service" {
  depends_on = [kubernetes_service.flask]

  provisioner "local-exec" {
    command = <<EOT
      oc expose service flask-service -n freakhill-dev || true
    EOT
  }
}
