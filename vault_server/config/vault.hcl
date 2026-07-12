storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true          # fine for local dev, enable TLS for production
}

api_addr     = "http://vault-server:8200"
cluster_addr = "http://vault-server:8201"
ui           = true
log_level    = "info"