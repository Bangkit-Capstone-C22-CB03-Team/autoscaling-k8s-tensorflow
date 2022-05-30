provider "kubernetes" {
  config_path = "~/.kube/config"
}

# configmap

resource "kubernetes_config_map_v1" "tfserving_configs" {
  metadata {
    name = "tfserving-configs"
  }

  data = {
    MODEL_NAME = "image_classifier"

    MODEL_PATH = "gs://sacred-armor-346113-bucket/resnet_101"
  }
}

# deployment

resource "kubernetes_deployment" "image_classifier" {
  metadata {
    name      = "image-classifier"
    namespace = "default"

    labels = {
      app = "image-classifier"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "image-classifier"
      }
    }

    template {
      metadata {
        labels = {
          app = "image-classifier"
        }
      }

      spec {
        container {
          name  = "tf-serving"
          # pake container registry jgn artifact registry biar lebih public & bisa di pull
          image = "tensorflow/serving"
          args  = ["--model_name=$(MODEL_NAME)", "--model_base_path=$(MODEL_PATH)"]

          port {
            name           = "http"
            container_port = 8501
            protocol       = "TCP"
          }

          port {
            name           = "grpc"
            container_port = 8500
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = "tfserving-configs"
            }
          }

          # machine type = n2d-highmem-4 (4 vCPUs, 32GB RAM)
          resources {
            # limits = {
            #   cpu = "3"

            #   memory = "8Gi"
            # }
            requests = {
              cpu = "3"

              memory = "4Gi"
            }
          }

          readiness_probe {
            tcp_socket {
              port = "8500"
            }

            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 10
          }

          image_pull_policy = "IfNotPresent"
        }
      }
    }
  }
}

# service

resource "kubernetes_service" "image_classifier" {
  metadata {
    name      = "image-classifier"
    namespace = "default"

    labels = {
      app = "image-classifier"
    }
  }

  spec {
    port {
      name     = "tf-serving-grpc"
      protocol = "TCP"
      port     = 8500
    }

    port {
      name     = "tf-serving-http"
      protocol = "TCP"
      port     = 8501
    }

    selector = {
      app = "image-classifier"
    }

    type = "LoadBalancer"
  }
}

