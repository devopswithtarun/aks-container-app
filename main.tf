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
