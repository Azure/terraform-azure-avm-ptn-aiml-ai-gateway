mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-template-test/providers/Microsoft.Network/virtualNetworks/avm-template-test"
  }
}

variables {
  address_space    = ["10.0.0.0/16"]
  enable_telemetry = false
  location         = "eastus"
  name             = "avm-template-test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-template-test"
  tags = {
    purpose = "template-test"
  }
}

run "creates_virtual_network_starter" {
  command = apply

  assert {
    condition     = output.name == var.name && output.resource_id == azapi_resource.this.id
    error_message = "The starter outputs must identify the created virtual network."
  }

  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location && azapi_resource.this.tags == var.tags
    error_message = "The starter must preserve the caller's parent, location, and tags."
  }

  assert {
    condition     = azapi_resource.this.type == var.resource_types.network_virtual_networks
    error_message = "The starter must use its configurable virtual-network resource type."
  }

  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        addressSpace = {
          addressPrefixes = var.address_space
        }
      }
    })
    error_message = "The starter body must contain exactly the supplied address prefixes."
  }
}

run "rejects_invalid_address_space" {
  command = plan

  variables {
    address_space = ["not-a-cidr"]
  }

  expect_failures = [var.address_space]
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "_invalid"
  }

  expect_failures = [var.name]
}

run "rejects_invalid_parent_scope" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "uses_retry_and_timeouts" {
  command = apply

  variables {
    retry = {
      error_message_regex  = ["TooManyRequests"]
      interval_seconds     = 5
      max_interval_seconds = 30
    }
    timeouts = {
      create = "45m"
      delete = "20m"
      read   = "5m"
      update = "30m"
    }
  }

  assert {
    condition     = azapi_resource.this.retry.error_message_regex == var.retry.error_message_regex && azapi_resource.this.retry.interval_seconds == var.retry.interval_seconds && azapi_resource.this.retry.max_interval_seconds == var.retry.max_interval_seconds
    error_message = "The starter must apply all supplied retry settings."
  }

  assert {
    condition     = azapi_resource.this.timeouts.create == var.timeouts.create && azapi_resource.this.timeouts.delete == var.timeouts.delete && azapi_resource.this.timeouts.read == var.timeouts.read && azapi_resource.this.timeouts.update == var.timeouts.update
    error_message = "The starter must apply every supplied operation timeout."
  }
}
