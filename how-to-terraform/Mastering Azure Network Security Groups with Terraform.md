# How to Create Azure Network Security Groups in Terraform

**Author:** nawazdhandala 1**Tags:** Terraform, Azure, NSG, Network Security, Firewall Rules, Infrastructure as Code 1  
Azure Network Security Groups (NSGs) act as virtual firewalls for your resources, containing rules that allow or deny network traffic based on source, destination, port, and protocol 2\. Every subnet and network interface in Azure can have an NSG attached, giving you fine-grained control over traffic flow 2\. Managing NSGs through Terraform is essential because security rules tend to grow organically; without infrastructure as code, NSGs can become full of forgotten rules 2\. Terraform keeps your security rules auditable and reviewable 2\.

### Prerequisites

* **Terraform 1.0** or later 3  
* **Azure CLI** authenticated 3  
* **Azure subscription ID** available for provider configuration 3  
* An existing **VNet and subnets** (or create them alongside the NSGs) 3

### Provider Configuration

terraform {  
  required\_providers {  
    azurerm \= {  
      source  \= "hashicorp/azurerm"  
      version \= "\~\> 4.0"  
    }  
  }  
}

provider "azurerm" {  
  features {}  
  subscription\_id \= var.subscription\_id  
}

variable "subscription\_id" {  
  description \= "Azure subscription ID where the resources will be managed"  
  type        \= string  
}

\# Reference an existing resource group  
data "azurerm\_resource\_group" "networking" {  
  name \= "rg-networking-prod-eus"  
}  
3

### Creating a Basic NSG

\# Network Security Group for the web tier  
resource "azurerm\_network\_security\_group" "web" {  
  name                \= "nsg-web-prod"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name

  tags \= {  
    Environment \= "production"  
    Tier        \= "web"  
    ManagedBy   \= "terraform"  
  }  
}  
4

### Defining Security Rules

Rules can be defined inline within the NSG or as separate resources 4\. Separate resources are generally better for complex configurations because they are easier to manage independently 4\.  
\# Allow HTTP from the internet  
resource "azurerm\_network\_security\_rule" "allow\_http" {  
  name                        \= "Allow-HTTP-Inbound"  
  priority                    \= 100  
  direction                   \= "Inbound"  
  access                      \= "Allow"  
  protocol                    \= "Tcp"  
  source\_port\_range           \= "\*"  
  destination\_port\_range      \= "80"  
  source\_address\_prefix       \= "Internet"  
  destination\_address\_prefix  \= "\*"  
  resource\_group\_name         \= data.azurerm\_resource\_group.networking.name  
  network\_security\_group\_name \= azurerm\_network\_security\_group.web.name  
}

\# Allow HTTPS from the internet  
resource "azurerm\_network\_security\_rule" "allow\_https" {  
  name                        \= "Allow-HTTPS-Inbound"  
  priority                    \= 110  
  direction                   \= "Inbound"  
  access                      \= "Allow"  
  protocol                    \= "Tcp"  
  source\_port\_range           \= "\*"  
  destination\_port\_range      \= "443"  
  source\_address\_prefix       \= "Internet"  
  destination\_address\_prefix  \= "\*"  
  resource\_group\_name         \= data.azurerm\_resource\_group.networking.name  
  network\_security\_group\_name \= azurerm\_network\_security\_group.web.name  
}

\# Allow SSH from a specific IP range (management access)  
resource "azurerm\_network\_security\_rule" "allow\_ssh" {  
  name                        \= "Allow-SSH-Management"  
  priority                    \= 200  
  direction                   \= "Inbound"  
  access                      \= "Allow"  
  protocol                    \= "Tcp"  
  source\_port\_range           \= "\*"  
  destination\_port\_range      \= "22"  
  source\_address\_prefix       \= "10.0.255.0/24"  
  destination\_address\_prefix  \= "\*"  
  resource\_group\_name         \= data.azurerm\_resource\_group.networking.name  
  network\_security\_group\_name \= azurerm\_network\_security\_group.web.name  
}

\# Deny all other inbound traffic (explicit deny)  
resource "azurerm\_network\_security\_rule" "deny\_all\_inbound" {  
  name                        \= "Deny-All-Inbound"  
  priority                    \= 4096  
  direction                   \= "Inbound"  
  access                      \= "Deny"  
  protocol                    \= "\*"  
  source\_port\_range           \= "\*"  
  destination\_port\_range      \= "\*"  
  source\_address\_prefix       \= "\*"  
  destination\_address\_prefix  \= "\*"  
  resource\_group\_name         \= data.azurerm\_resource\_group.networking.name  
  network\_security\_group\_name \= azurerm\_network\_security\_group.web.name  
}  
5

### NSG with Inline Rules

For simpler NSGs, inline rules keep everything in one block 6\.  
\# Application tier NSG with inline rules  
resource "azurerm\_network\_security\_group" "app" {  
  name                \= "nsg-app-prod"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name

  \# Allow traffic from web tier on port 8080  
  security\_rule {  
    name                       \= "Allow-Web-To-App"  
    priority                   \= 100  
    direction                  \= "Inbound"  
    access                     \= "Allow"  
    protocol                   \= "Tcp"  
    source\_port\_range          \= "\*"  
    destination\_port\_range     \= "8080"  
    source\_address\_prefix      \= "10.0.1.0/24"  
    destination\_address\_prefix \= "\*"  
  }

  \# Allow health check probes from Azure Load Balancer  
  security\_rule {  
    name                       \= "Allow-LB-Probes"  
    priority                   \= 110  
    direction                  \= "Inbound"  
    access                     \= "Allow"  
    protocol                   \= "Tcp"  
    source\_port\_range          \= "\*"  
    destination\_port\_range     \= "8080"  
    source\_address\_prefix      \= "AzureLoadBalancer"  
    destination\_address\_prefix \= "\*"  
  }

  \# Deny all other inbound  
  security\_rule {  
    name                       \= "Deny-All-Inbound"  
    priority                   \= 4096  
    direction                  \= "Inbound"  
    access                     \= "Deny"  
    protocol                   \= "\*"  
    source\_port\_range          \= "\*"  
    destination\_port\_range     \= "\*"  
    source\_address\_prefix      \= "\*"  
    destination\_address\_prefix \= "\*"  
  }

  tags \= {  
    Environment \= "production"  
    Tier        \= "application"  
  }  
}  
6

### Associating NSGs with Subnets

NSGs only take effect when associated with a subnet or network interface 7\.  
\# Reference the existing VNet and subnets  
data "azurerm\_virtual\_network" "main" {  
  name                \= "vnet-main-prod-eus"  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name  
}

data "azurerm\_subnet" "web" {  
  name                 \= "snet-web"  
  virtual\_network\_name \= data.azurerm\_virtual\_network.main.name  
  resource\_group\_name  \= data.azurerm\_resource\_group.networking.name  
}

data "azurerm\_subnet" "app" {  
  name                 \= "snet-app"  
  virtual\_network\_name \= data.azurerm\_virtual\_network.main.name  
  resource\_group\_name  \= data.azurerm\_resource\_group.networking.name  
}

\# Associate NSG with web subnet  
resource "azurerm\_subnet\_network\_security\_group\_association" "web" {  
  subnet\_id                 \= data.azurerm\_subnet.web.id  
  network\_security\_group\_id \= azurerm\_network\_security\_group.web.id  
}

\# Associate NSG with app subnet  
resource "azurerm\_subnet\_network\_security\_group\_association" "app" {  
  subnet\_id                 \= data.azurerm\_subnet.app.id  
  network\_security\_group\_id \= azurerm\_network\_security\_group.app.id  
}  
7

### Application Security Groups

Application Security Groups (ASGs) let you group VM network interfaces logically and reference them in NSG rules instead of using IP addresses 8\. This makes rules cleaner and more maintainable 8\.  
\# ASG for web servers  
resource "azurerm\_application\_security\_group" "web\_servers" {  
  name                \= "asg-web-servers"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name  
  tags \= { Role \= "web" }  
}

\# ASG for app servers  
resource "azurerm\_application\_security\_group" "app\_servers" {  
  name                \= "asg-app-servers"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name  
  tags \= { Role \= "application" }  
}

\# ASG for database servers  
resource "azurerm\_application\_security\_group" "db\_servers" {  
  name                \= "asg-db-servers"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name  
  tags \= { Role \= "database" }  
}

\# NSG rules using ASGs instead of IP addresses  
resource "azurerm\_network\_security\_group" "asg\_based" {  
  name                \= "nsg-asg-rules"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name

  \# Allow web to app communication  
  security\_rule {  
    name                                    \= "Allow-Web-To-App"  
    priority                                \= 100  
    direction                               \= "Inbound"  
    access                                  \= "Allow"  
    protocol                                \= "Tcp"  
    source\_port\_range                       \= "\*"  
    destination\_port\_range                  \= "8080"  
    source\_application\_security\_group\_ids   \= \[azurerm\_application\_security\_group.web\_servers.id\]  
    destination\_application\_security\_group\_ids \= \[azurerm\_application\_security\_group.app\_servers.id\]  
  }

  \# Allow app to database communication  
  security\_rule {  
    name                                    \= "Allow-App-To-DB"  
    priority                                \= 110  
    direction                               \= "Inbound"  
    access                                  \= "Allow"  
    protocol                                \= "Tcp"  
    source\_port\_range                       \= "\*"  
    destination\_port\_ranges                 \= \["3306", "5432"\]  
    source\_application\_security\_group\_ids   \= \[azurerm\_application\_security\_group.app\_servers.id\]  
    destination\_application\_security\_group\_ids \= \[azurerm\_application\_security\_group.db\_servers.id\]  
  }

  tags \= { Environment \= "production" }  
}  
8

### Dynamic Rules from a Variable

When you have many rules, you can define them in a variable and generate them dynamically 9\.  
variable "nsg\_rules" {  
  description \= "List of NSG rules"  
  type \= list(object({  
    name                       \= string  
    priority                   \= number  
    direction                  \= string  
    access                     \= string  
    protocol                   \= string  
    source\_port\_range          \= string  
    destination\_port\_range     \= string  
    source\_address\_prefix      \= string  
    destination\_address\_prefix \= string  
  }))  
  default \= \[  
    {  
      name                       \= "Allow-HTTP"  
      priority                   \= 100  
      direction                  \= "Inbound"  
      access                     \= "Allow"  
      protocol                   \= "Tcp"  
      source\_port\_range          \= "\*"  
      destination\_port\_range     \= "80"  
      source\_address\_prefix      \= "Internet"  
      destination\_address\_prefix \= "\*"  
    },  
    {  
      name                       \= "Allow-HTTPS"  
      priority                   \= 110  
      direction                  \= "Inbound"  
      access                     \= "Allow"  
      protocol                   \= "Tcp"  
      source\_port\_range          \= "\*"  
      destination\_port\_range     \= "443"  
      source\_address\_prefix      \= "Internet"  
      destination\_address\_prefix \= "\*"  
    },  
    {  
      name                       \= "Allow-SSH-Bastion"  
      priority                   \= 200  
      direction                  \= "Inbound"  
      access                     \= "Allow"  
      protocol                   \= "Tcp"  
      source\_port\_range          \= "\*"  
      destination\_port\_range     \= "22"  
      source\_address\_prefix      \= "10.0.255.0/24"  
      destination\_address\_prefix \= "\*"  
    }  
  \]  
}

\# NSG with dynamic rules  
resource "azurerm\_network\_security\_group" "dynamic\_rules" {  
  name                \= "nsg-dynamic-prod"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name

  dynamic "security\_rule" {  
    for\_each \= var.nsg\_rules  
    content {  
      name                       \= security\_rule.value.name  
      priority                   \= security\_rule.value.priority  
      direction                  \= security\_rule.value.direction  
      access                     \= security\_rule.value.access  
      protocol                   \= security\_rule.value.protocol  
      source\_port\_range          \= security\_rule.value.source\_port\_range  
      destination\_port\_range     \= security\_rule.value.destination\_port\_range  
      source\_address\_prefix      \= security\_rule.value.source\_address\_prefix  
      destination\_address\_prefix \= security\_rule.value.destination\_address\_prefix  
    }  
  }

  tags \= { Environment \= "production" }  
}  
9

### Virtual Network Flow Logs

NSG flow logs are being retired, and Azure no longer allows creating new ones 10\. For new deployments, enable **virtual network flow logs** to capture traffic data for analysis and troubleshooting 10\.  
\# Storage account for flow logs  
resource "azurerm\_storage\_account" "flow\_logs" {  
  name                     \= "stflowlogsprodeus"  
  resource\_group\_name      \= data.azurerm\_resource\_group.networking.name  
  location                 \= data.azurerm\_resource\_group.networking.location  
  account\_tier             \= "Standard"  
  account\_replication\_type \= "LRS"  
  tags \= { Purpose \= "network-flow-logs" }  
}

\# Log Analytics workspace for flow log analysis  
resource "azurerm\_log\_analytics\_workspace" "networking" {  
  name                \= "law-networking-prod"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name  
  sku                 \= "PerGB2018"  
  retention\_in\_days   \= 30  
  tags \= { Purpose \= "network-monitoring" }  
}

\# Network watcher  
resource "azurerm\_network\_watcher" "main" {  
  name                \= "nw-prod-eastus"  
  location            \= data.azurerm\_resource\_group.networking.location  
  resource\_group\_name \= data.azurerm\_resource\_group.networking.name  
}

\# Virtual network flow log  
resource "azurerm\_network\_watcher\_flow\_log" "main" {  
  network\_watcher\_name \= azurerm\_network\_watcher.main.name  
  resource\_group\_name  \= data.azurerm\_resource\_group.networking.name  
  name                 \= "flowlog-vnet-main"  
  target\_resource\_id   \= data.azurerm\_virtual\_network.main.id  
  storage\_account\_id   \= azurerm\_storage\_account.flow\_logs.id  
  enabled              \= true  
  version              \= 2

  retention\_policy {  
    enabled \= true  
    days    \= 30  
  }

  traffic\_analytics {  
    enabled               \= true  
    workspace\_id          \= azurerm\_log\_analytics\_workspace.networking.workspace\_id  
    workspace\_region      \= azurerm\_log\_analytics\_workspace.networking.location  
    workspace\_resource\_id \= azurerm\_log\_analytics\_workspace.networking.id  
    interval\_in\_minutes   \= 10  
  }  
}  
10

### Outputs

output "web\_nsg\_id" {  
  description \= "ID of the web tier NSG"  
  value       \= azurerm\_network\_security\_group.web.id  
}

output "app\_nsg\_id" {  
  description \= "ID of the app tier NSG"  
  value       \= azurerm\_network\_security\_group.app.id  
}

output "asg\_ids" {  
  description \= "Application Security Group IDs"  
  value \= {  
    web \= azurerm\_application\_security\_group.web\_servers.id  
    app \= azurerm\_application\_security\_group.app\_servers.id  
    db  \= azurerm\_application\_security\_group.db\_servers.id  
  }  
}  
11

### Monitoring Network Security

NSGs silently drop traffic when rules deny it, which can lead to confusing connectivity issues 12\. Using a monitoring tool like OneUptime can help track application endpoints and alert you when connections fail 12\. Correlating these alerts with virtual network flow logs helps determine if a firewall rule is the cause 12\.

### Summary

Network Security Groups are a primary tool for controlling traffic in Azure 12\. Defining them in Terraform alongside VNet and subnet configurations ensures your security posture is version-controlled and reviewable 12\. Use Application Security Groups when possible for better readability and maintainability, and always enable flow logs on production networks for troubleshooting 12\.  
