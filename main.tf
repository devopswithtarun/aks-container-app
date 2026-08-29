# Resource group — the container for everything in this project
resource "azurerm_resource_group" "aks_app" {
  name     = "rg-aks-container-app"
  location = "ukwest"
}

# Azure Container Registry — private storage for our Docker images.
# SKU "Basic" is the cheapest tier, plenty for a small personal project.
resource "azurerm_container_registry" "acr" {
  name                = "acraksappdemo"
  resource_group_name = azurerm_resource_group.aks_app.name
  location            = azurerm_resource_group.aks_app.location
  sku                 = "Basic"

  # Allows Docker CLI / kubectl to authenticate with a simple admin
  # username+password instead of full Azure AD auth — simpler for a
  # personal project. In a real company, this would usually be disabled
  # in favour of managed identity or service principal auth.
  admin_enabled = true
}

# --- AKS Cluster ---
# This is the actual Kubernetes control plane + worker nodes.
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-container-app-cluster"
  location            = azurerm_resource_group.aks_app.location
  resource_group_name = azurerm_resource_group.aks_app.name
  dns_prefix          = "aksapp"

  # Azure enables this by default on new clusters; declaring it
  # explicitly here stops Terraform from trying to "reset" it during
  # any future update, which Azure doesn't allow once it's already on.
  oidc_issuer_enabled = true

  # The "default_node_pool" is the group of actual VMs that run your
  # containers. node_count = 1 keeps cost minimal for a demo — a real
  # production cluster would run at least 2-3 for redundancy.
  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s_v2"
  }

  # AKS needs an identity to manage other Azure resources on your behalf
  # (like creating load balancers for Services). SystemAssigned means
  # Azure creates and manages this identity automatically.
  identity {
    type = "SystemAssigned"
  }

  # This is what actually turns on Container Insights — without this
  # block, the Log Analytics workspace below would exist but sit empty,
  # since nothing would be sending data into it.
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_logs.id
  }
}

# This grants the AKS cluster's identity permission to actually pull
# images from ACR. Without this, kubectl can create the Deployment, but
# every pod will fail with an image pull error — a very common real-world
# AKS + ACR troubleshooting scenario.
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                    = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name            = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# --- Monitoring: Container Insights ---
# This is a specialized Log Analytics workspace. Once linked to the AKS
# cluster (via the oms_agent block added to the cluster resource above),
# Azure automatically collects pod CPU/memory metrics, logs, and
# container restart events — matching the "Azure Monitor" box in the
# architecture diagram.

resource "azurerm_log_analytics_workspace" "aks_logs" {
  name                = "law-aks-app-demo"
  location            = azurerm_resource_group.aks_app.location
  resource_group_name = azurerm_resource_group.aks_app.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
