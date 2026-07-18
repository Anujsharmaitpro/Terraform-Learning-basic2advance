# Terraform Functions Cheat Sheet (Azure Context)

A quick-reference guide for Terraform functions categorized by type, including a one-line reminder and a practical Azure-specific example for each.

---

## Numeric Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `ceil` | Returns the closest whole number greater than or equal to the given value. | ``ceil(var.os_disk_gb / 10)`` to dynamically calculate a rounded-up managed disk tier scale. |
| `floor` | Returns the closest whole number less than or equal to the given value. | ``floor(var.total_budget / azurerm_linux_virtual_machine.vm.price)`` to find the minimum VM instances you can afford. |
| `log` | Returns the logarithm of a given number in a given base. | ``log(var.azure_eventhub_partitions, 2)`` to evaluate binary tree distribution layers for Event Hub shards. |
| `max` | Returns the greatest number from a set of one or more numbers. | ``max(3, var.aks_node_count)`` to ensure an AKS cluster never falls below a high-availability baseline of 3 nodes. |
| `min` | Returns the smallest number from a set of one or more numbers. | ``min(250, var.max_pods_per_node)`` to cap maximum AKS pod allocations due to Azure CNI network limitations. |
| `parseint` | Parses a string as an integer in a specified base. | ``parseint(regex("[0-9]+", azurerm_virtual_network.vnet.name), 10)`` to isolate a numeric environment sequence out of a VNet's name. |
| `pow` | Raises the first argument to the power of the second argument. | ``pow(2, (32 - var.subnet_mask_bits))`` to figure out the total mathematical host IP addresses available inside an Azure Subnet block. |
| `signum` | Determines the sign of a number, returning -1, 0, or 1. | ``signum(var.azure_monetary_credits_remaining)`` to check if a subscription spending limit balance is positive, zero, or negative. |

---

## String Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `chomp` | Removes newline characters from the end of a string. | ``chomp(file("${path.module}/azure_ssh_key.pub"))`` to clean up trailing line breaks from a public key file before inserting it into an Azure Linux VM. |
| `endswith` | Returns true if the given string ends with the specified suffix. | ``endswith(azurerm_storage_account.st.name, "st")`` to validate that a storage account complies with enterprise standard naming suffixes. |
| `format` | Produces a string by formatting values according to a specification string. | ``format("vnet-%s-%s-01", var.environment, var.location)`` to systematically generate an official Azure resource naming structure. |
| `formatlist` | Produces a list of strings by formatting multiple values according to a specification. | ``formatlist("%s/subnets/default", azurerm_virtual_network.vnets[*].id)`` to cleanly construct a list of explicit default subnet resource paths across multiple VNets. |
| `indent` | Adds spaces to the beginning of each line in a multi-line string (except the first). | ``indent(2, var.cloud_init_script)`` to format custom multiline bash script payloads inside an Azure VM's YAML-driven `custom_data` block. |
| `join` | Concatenates elements of a string list together using a specified separator. | ``join(",", azurerm_network_security_group.nsg.security_rule[*].destination_port_range)`` to squash multiple distinct NSG rules into a single comma-separated display value. |
| `lower` | Converts all cased letters in a string to lowercase. | ``lower(var.storage_account_name)`` to force strict globally unique lowercase naming requirements mandatory for Azure Storage Accounts. |
| `regex` | Applies a regular expression to a string and returns the matching substrings. | ``regex("subscriptions/(.*?)/", azurerm_resource_group.rg.id)[0]`` to extract the literal 36-character Azure Subscription ID from a resource group's ID string. |
| `regexall` | Applies a regular expression to a string and returns a list of all matches. | ``regexall("prod", azurerm_management_group.mg.id)`` to check how many times the keyword "prod" appears within an Azure Management Group hierarchy path. |
| `replace` | Searches a string for a substring and replaces each occurrence. | ``replace(azurerm_public_ip.pip.ip_address, ".", "-")`` to flip periods to dashes when creating a clean custom DNS subdomain routing pointing to an Azure Public IP. |
| `split` | Divides a given string into a list at all occurrences of a given separator. | ``split("/", azurerm_subnet.example.id)[4]`` to isolate and grab the exact Azure Resource Group name hidden inside a massive subnet resource identifier URL. |
| `startswith` | Returns true if the given string begins with the specified prefix. | ``startswith(azurerm_resource_group.rg.name, "rg-")`` to run a validation check asserting that an Azure Resource Group adheres to corporate tagging prefixes. |
| `strcontains` | Returns true if the first string contains the second string. | ``strcontains(azurerm_linux_virtual_machine.vm.size, "Standard_D")`` to verify if a deployed Azure VM belongs to the general purpose D-series hardware family. |
| `strrev` | Reverses the characters in a string. | ``strrev(var.obfuscated_azure_kv_secret)`` to invert or validate custom masked verification patterns matching an Azure Key Vault secret string. |
| `substr` | Extracts a substring from a given string using a defined offset and length. | ``substr(var.company_resource_prefix, 0, 24)`` to safely slice an overly long name down to 24 characters to respect Azure Storage Account maximum character boundaries. |
| `templatestring` | Renders a string as a template using a provided set of variables. | ``templatestring("${prefix}-rg", { prefix = "azure-core" })`` to evaluate dynamic inline string building templates for a resource group. |
| `title` | Converts the first letter of each word in a string to uppercase. | ``title(azurerm_resource_group.rg.location)`` to transform a location string like "eastus" into a capitalized title ("Eastus") for business reporting tags. |
| `trim` | Removes a specified set of characters from the start and end of a string. | ``trim(var.azure_tag_value, " \"")`` to scrub accidental hanging quote marks or stray trailing spaces clean out of Azure resource tagging inputs. |
| `trimprefix` | Removes a specified prefix from the start of a string. | ``trimprefix(azurerm_resource_group.rg.id, "/subscriptions/")`` to cleanly cut away the repetitive leading subscription path block out of an Azure resource string. |
| `trimsuffix` | Removes a specified suffix from the end of a string. | ``trimsuffix(azurerm_linux_virtual_machine.vm.name, "-vm")`` to strip a predictable suffix off an Azure VM resource name to capture the pure raw base hostname. |
| `trimspace` | Removes all whitespace characters from the start and end of a string. | ``trimspace(var.azure_client_secret)`` to eliminate accidental trailing spaces pasted into an Azure Service Principal password variable input block. |
| `upper` | Converts all cased letters in a string to uppercase. | ``upper(var.environment_tier)`` to force small environment names into clear uppercase callouts (e.g., "PROD", "DEV") inside Azure Tag values. |

---

## Collection Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `alltrue` | Returns true if all elements in a collection are true or if the collection is empty. | ``alltrue([for ip in azurerm_public_ip.pip : ip.sku == "Standard"])`` to evaluate whether every single public IP in a deployment complies with the "Standard" SKU policy. |
| `anytrue` | Returns true if any element in a collection is true. | ``anytrue([for s in azurerm_subnet.sub : s.private_endpoint_network_policies_enabled])`` to instantly verify if at least one Azure Subnet has active private endpoint tracking parameters turned on. |
| `chunklist` | Splits a single list into fixed-size chunks, returning a list of lists. | ``chunklist(azurerm_linux_virtual_machine.vm[*].id, 5)`` to group a huge array of Azure VM instances into smaller batch groups of 5 for progressive post-deployment maintenance scripts. |
| `coalesce` | Returns the first argument from a list that is not null or an empty string. | ``coalesce(var.custom_dns_server, "168.63.129.16")`` to fall back instantly to the native default Azure DNS recursive resolver IP if no custom server string is supplied. |
| `coalescelist` | Returns the first list argument that is not empty. | ``coalescelist(var.override_nsg_ids, [azurerm_network_security_group.default.id])`` to prioritize applying custom user-defined Azure NSG IDs, dropping back to a default array if empty. |
| `compact` | Takes a list of strings and returns a new list with null or empty strings removed. | ``compact([var.primary_dns, var.secondary_dns, var.backup_dns])`` to purge out unconfigured blank array inputs from an Azure VNet custom DNS configuration setting block. |
| `concat` | Combines two or more lists into a single consolidated list. | ``concat(azurerm_subnet.dmz.address_prefixes, azurerm_subnet.internal.address_prefixes)`` to aggregate diverse Azure subnet CIDR allocations into one unified network summary index. |
| `contains` | Checks if a list, tuple, or set contains a specific target value. | ``contains(var.allowed_azure_regions, azurerm_resource_group.rg.location)`` to ensure a resource group's geography destination matches elements listed in an allowed organizational location map. |
| `distinct` | Removes duplicate elements from a list, returning unique values. | ``distinct(azurerm_network_interface.nic[*].resource_group_name)`` to assemble a clean, non-repeating summary list of all unique Azure Resource Groups hosting network cards. |
| `element` | Retrieves a single element from a list using its index. | ``element(azurerm_virtual_network.vnet.subnet[*].id, 0)`` to reliably pull the specific root subnet ID string from an Azure VNet subnet deployment array. |
| `flatten` | Collapses nested lists into a single, flat sequence of contents. | ``flatten([for vnet in azurerm_virtual_network.vnets : vnet.subnet[*].address_prefixes])`` to gather multi-layered subnet IP ranges scattered across diverse VNets into a single flat array. |
| `index` | Finds the index of the first element that matches a given value in a list. | ``index(var.azure_region_priority, "eastus2")`` to discover the exact sorting ranking index of a specific Azure region out of an order-of-preference variable array. |
| `keys` | Extracts and returns a list containing all the keys from a map. | ``keys(azurerm_resource_group.rg.tags)`` to generate a string array containing only the tag key metadata properties actively assigned to an Azure Resource Group. |
| `length` | Returns the total number of elements in a list, map, or string. | ``length(azurerm_virtual_network.vnet.subnet)`` to gauge exactly how many individual subnet child blocks are configured inside an Azure Virtual Network resource definition. |
| `list` | *Deprecated:* Casts collections into a list structure. | Use `tolist(azurerm_public_ip.pip[*].ip_address)` to securely cast an array collection of Azure public IP outputs into a modern, strongly-typed list structure. |
| `lookup` | Retrieves the value of a single element from a map given its key name. | ``lookup(var.sku_mapping, "production", "Standard_D2s_v5")`` to map an environment key to an Azure VM size, picking `Standard_D2s_v5` if no specific tier match is declared. |
| `map` | *Deprecated:* Casts parameters into a map type. | Use `tomap({"rg" = azurerm_resource_group.rg.name})` to map Azure parameters into a strongly-typed key-value collection block. |
| `matchkeys` | Creates a subset of one list whose indexes match specified values in a parallel list. | ``matchkeys(local.vm_names, local.vm_power_states, ["Deallocated"])`` to separate out a distinct list of Azure VM names whose index match an inactive "Deallocated" operational status. |
| `merge` | Combines an arbitrary number of maps or objects into a single map/object. | ``merge(var.global_corporate_tags, {"CostCenter" = "IT-Azure"})`` to join core enterprise tagging requirements with resource-specific Azure tagging metrics. |
| `one` | Returns the unique element from a single-item collection, null if empty, or throws an error if multiple exist. | ``one(azurerm_public_ip.pip[*].ip_address)`` to safely capture a single IP string when zero or one Azure PIPs are conditionally deployed, shielding the code from unexpected array errors. |
| `range` | Generates a sequential list of numbers using a start, limit, and step value. | ``range(0, var.azure_aks_node_pool_count)`` to generate a strict incremental index sequence for setting up looped resource attachments matching an AKS node pool size. |
| `reverse` | Produces a new sequence of the same length with the order of elements inverted. | ``reverse(azurerm_application_gateway.agw.backend_address_pool[*].name)`` to invert the failover execution sequences matching routing backends inside an Azure Application Gateway. |
| `setintersection` | Takes multiple sets and returns a single set containing only their common elements. | ``setintersection(var.requested_vm_sizes, ["Standard_B1s", "Standard_D2s_v5"])`` to cross-reference and approve only the corporate-sanctioned Azure VM SKUs overlapping with a user's request list. |
| `setproduct` | Finds all possible combinations of elements across sets by computing the Cartesian product. | ``setproduct(["eastus", "westus"], ["frontend", "backend"])`` to quickly produce coordinate permutations for scaling out regional subnets across Azure locations. |
| `setsubtract` | Returns a new set containing elements from the first set that are not present in the second. | ``setsubtract(var.all_azure_regions, ["chinaeast", "germanycentral"])`` to filter out sovereign or restricted global cloud locations from a target deployment map. |
| `setunion` | Combines multiple sets into a single set containing all unique elements. | ``setunion(var.office_public_ips, var.admin_jumpbox_ips)`` to join multiple lists of discrete network addresses into one master firewall whitelist target set for an Azure Key Vault. |
| `slice` | Extracts a specific subset of consecutive elements from within a list. | ``slice(azurerm_virtual_network.vnet.address_space, 0, 1)`` to pick and isolate the absolute primary IP address space range out of an Azure VNet configuration array. |
| `sort` | Sorts a list of strings alphabetically (lexicographically). | ``sort(azurerm_storage_account.st[*].name)`` to organize a collection of dynamically generated Azure storage names alphabetically for streamlined output reporting formatting. |
| `sum` | Calculates and returns the total sum of a list or set of numbers. | ``sum(azurerm_managed_disk.disk[*].disk_size_gb)`` to aggregate individual storage sizing units into a single combined calculation representing the total data payload footprint across all Azure disks. |
| `transpose` | Swaps keys and values within a map of string lists to produce a new map. | ``transpose({"rg-alpha" = ["vm1", "vm2"], "rg-beta" = ["vm3"]})`` to reverse mapping models, linking Azure VMs back directly to their host Resource Groups. |
| `values` | Extracts and returns a list containing all the values from a map. | ``values(azurerm_resource_group.rg.tags)`` to extract a raw data array containing exclusively the metadata property values assigned within an Azure resource tagging block. |
| `zipmap` | Constructs a map by pairing a list of keys with a corresponding list of values. | ``zipmap(local.vm_names, azurerm_network_interface.nic[*].private_ip_address)`` to stitch a list of Azure virtual machine hostnames directly to their private IP mappings inside a clean dictionary map. |

---

## Encoding Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `base64decode` | Decodes a Base64-encoded string back into its original text. | ``base64decode(azurerm_key_vault_secret.cert.value)`` to translate an encrypted certificate credential extracted from an Azure Key Vault secret back into standard, plain-text syntax. |
| `base64encode` | Applies Base64 encoding to a raw text string. | ``base64encode(local.bash_setup_script)`` to translate a raw initialization shell script into a Base64 block format to map against an Azure Linux VM's `custom_data` parameter. |
| `base64gzip` | Compresses a string using gzip and encodes the result in Base64 format. | ``base64gzip(file("azure_vmss_init.yml"))`` to heavily compress large diagnostic configuration files before uploading them into an Azure Virtual Machine Scale Set payload block. |
| `csvdecode` | Decodes a CSV-formatted string into a representative list of maps. | ``csvdecode(file("azure_rbac_assignments.csv"))`` to read a flat spreadsheet file to mass-provision custom access roles across Azure subscription targets. |
| `jsondecode` | Parses a JSON string into native Terraform language types and structures. | ``jsondecode(azurerm_role_definition.custom.permissions[0].actions)`` to parse a raw JSON payload string of Azure RBAC actions down into an active, native data structure. |
| `jsonencode` | Encodes a Terraform value or structure into a valid JSON string. | ``jsonencode({"location" = azurerm_resource_group.rg.location})`` to cleanly format runtime context outputs into structural JSON configurations targeting an Azure Logic App webhook. |
| `textdecodebase64` | Decodes a Base64 string and interprets it using a specified character encoding. | ``textdecodebase64(var.b64_windows_config, "UTF-16")`` to translate custom legacy Windows/Azure OS logging outputs encoded in UTF-16 back into readable structures. |
| `textencodebase64` | Encodes a string's characters into a specified encoding, returning the result in Base64. | ``textencodebase64(var.app_config_text, "UTF-8")`` to strictly encode an App Service script profile payload using standard UTF-8 parameters ahead of pushing it into an Azure App Setting. |
| `urlencode` | Applies URL encoding transformation to a given string. | ``urlencode(azurerm_storage_account.st.primary_blob_endpoint)`` to safely transform special characters inside an Azure Storage endpoint URI string so it can be passed cleanly inside an HTTP REST API connection string. |
| `yamldecode` | Parses a subset of YAML text into native Terraform values. | ``yamldecode(file("azure-container-apps.yml"))`` to unpack external cloud configuration settings directly into active, structural mapping metrics for Azure Container Apps. |
| `yamlencode` | Encodes a given value into a valid YAML 1.2 block syntax string. | ``yamlencode({"azure_policy_remediation" = "deploy_if_not_exists"})`` to write out complex multi-nested corporate governance properties into clean YAML layouts for an Azure Policy Definition block. |

---

## Filesystem Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `abspath` | Converts a relative filesystem path string into an absolute path. | ``abspath("${path.module}/azure-policies")`` to resolve a fully qualified system file path pointing directly to a directory holding localized Azure Policy JSON scripts. |
| `dirname` | Removes the trailing file/directory portion from a path string to return the directory path. | ``dirname(var.azure_kube_config_path)`` to strip out a filename string to isolate exclusively the container folder tracking the path to an Azure AKS access credential file. |
| `pathexpand` | Replaces a leading `~` segment in a path with the current user's home directory. | ``pathexpand("~/.azure/azureProfile.json")`` to expand shorthand system variables into absolute local path targets pointing to the local machine's active Azure CLI login profile token. |
| `basename` | Strips the directory prefix from a path to return only the final file or folder name. | ``basename(azurerm_storage_blob.blob.url)`` to clip off extensive leading directory tracking URLs to isolate only the target filename hosted inside an Azure Storage Blob container. |
| `file` | Reads the raw contents of a local file at a given path and returns it as a string. | ``file("${path.module}/azure_arm_template.json")`` to import raw text configurations directly out of an underlying legacy Azure Resource Manager (ARM) blueprint document. |
| `fileexists` | Determines whether a valid file actually exists at the specified path. | ``fileexists("${path.module}/azure_sp_credentials.json")`` to execute an automated sanity check evaluating whether an explicit local Azure credential configuration file exists prior to triggering provider authentication sequences. |
| `fileset` | Enumerates a set of regular file names matching a given path and glob pattern. | ``fileset("${path.module}/policies", "*.json")`` to loop through and locate every discrete Azure custom policy definition script saved across a workspace folder tree. |
| `filebase64` | Reads a file directly from a path and returns its contents as a Base64-encoded string. | ``filebase64("${path.module}/azure_setup.ps1")`` to pull an external Windows PowerShell script file and format it into a Base64 configuration block targeting an Azure VM Custom Script Extension. |
| `templatefile` | Reads a file path and renders its contents as a template using provided variables. | ``templatefile("azure_init.tftpl", { admin_user = azurerm_linux_virtual_machine.vm.admin_username })`` to dynamically map active infrastructure data strings directly into an external server initialization script template. |

---

## Date and Time Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `formatdate` | Converts a given timestamp string into an alternative, custom time format. | ``formatdate("YYYY-MM-DD", timestamp())`` to generate a standardized creation date value string to assign directly into an Azure Resource Group tagging dashboard. |
| `plantimestamp` | Returns a UTC timestamp in RFC 3339 format at the time Terraform creates a plan. | ``plantimestamp()`` to set a definitive historical record block marking exactly when an Azure infrastructure modification plan execution was generated by the deployment engine. |
| `timeadd` | Adds a specific time duration (e.g., "2h") to a timestamp, returning a new timestamp. | ``timeadd(timestamp(), "720h")`` to add exactly 30 days onto the execution date to automatically schedule a lock termination threshold for an Azure Storage Immutability policy block. |
| `timecmp` | Compares two timestamps chronologically and returns -1, 0, or 1 based on their order. | ``timecmp(timestamp(), var.azure_migration_grace_period_end)`` to automatically evaluate if the current runtime date sits safely inside or past an official corporate Azure decommissioning timeline target. |
| `timestamp` | Returns the current UTC timestamp string in RFC 3339 format during execution. | ``timestamp()`` to map a runtime clock metric directly into an Azure resource group deployment block to trace precisely when creation actions occurred. |

---

## Hash and Crypto Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `base64sha256` | Computes a SHA256 hash of a string and returns the result with Base64 encoding. | ``base64sha256(var.azure_vm_admin_password)`` to translate an administrative string entry into a masked cryptographic signature for secure identity confirmation validation. |
| `base64sha512` | Computes a SHA512 hash of a string and returns the result with Base64 encoding. | ``base64sha512(var.azure_client_secret_string)`` to compute an intensely strong, high-bit validation footprint mapping against an internal Entra ID App registration parameter. |
| `bcrypt` | Hashes a string using the Blowfish cipher, formatted in Modular Crypt Format. | ``bcrypt(var.azure_vm_root_password)`` to generate a heavily secure, complex password hash structure required to initialize a local system root user profile inside an Azure Linux VM. |
| `filebase64sha256` | Hashes the raw content of a local file using SHA256, returning a Base64 string. | ``filebase64sha256("app_package.zip")`` to feed the `source_control_file_hash` attribute, forcing an Azure App Service zip deployment to update only if the underlying code package binary alters. |
| `filebase64sha512` | Hashes the raw content of a local file using SHA512, returning a Base64 string. | ``filebase64sha512("large-os-image.vhd")`` to generate a rigorous validation tracking hash verifying the raw structural identity of an OS image asset targeting an Azure Compute Gallery. |
| `filemd5` | Computes the MD5 hash of a local file's contents, returning a hex string. | ``filemd5("index.html")`` to populate the `source_md5` parameter of an `azurerm_storage_blob` file resource, ensuring the blob changes only when the source content updates. |
| `filesha1` | Computes the SHA1 hash of a local file's contents, returning a hex string. | ``filesha1("gateway_cert.pfx")`` to isolate a clear cryptographic certificate thumbprint string format to supply directly to an Azure Application Gateway SSL routing listener. |
| `filesha256` | Calculates the SHA-256 hash of a local file's contents, returning a hex string. | ``filesha256("azure_extension.sh")`` to build a robust data-integrity security signature validating custom VM extensions code packages inside Azure. |
| `filesha512` | Calculates the SHA-512 hash of a local file's contents, returning a hex string. | ``filesha512("secure_image.raw")`` to run deep-level file validation auditing steps against localized disk image artifacts designated for Azure specialized virtual machines. |
| `md5` | Computes the MD5 hash of a given text string, returning hexadecimal digits. | ``md5(var.azure_diagnostic_setting_name)`` to compress long name parameters into short, standardized string patterns to keep Azure monitoring resources tidy and uniquely identifiable. |
| `rsadecrypt` | Decrypts an RSA-encrypted ciphertext using a private key to return cleartext. | ``rsadecrypt(var.encrypted_azure_vm_secret, file("azure_private_key.pem"))`` to unpack an encrypted credential block locally before piping the clean data into a sensitive Azure configuration property. |
| `sha1` | Computes the SHA1 hash of a given text string, returning hexadecimal digits. | ``sha1(azurerm_resource_group.rg.id)`` to process an Azure resource's unique system path identifier into a quick, deterministic 40-character tracking signature. |
| `sha256` | Computes the SHA256 hash of a given text string, returning hexadecimal digits. | ``sha256(var.azure_service_principal_secret)`` to convert a sensitive Entra ID app password into a standard hexadecimal verification hash. |
| `sha512` | Computes the SHA512 hash of a given text string, returning hexadecimal digits. | ``sha512(var.azure_storage_shared_access_key)`` to hash a raw Azure Storage account primary master key into a thorough hex fingerprint string for compliance auditing. |
| `uuid` | Generates a universally unique identifier (UUID) string using random bytes. | ``uuid()`` to generate a completely randomized 36-character GUID token string to assign as a unique tracking tag across core Azure infrastructure resources. |
| `uuidv5` | Generates a name-based UUID, as described in RFC 4122 section 4.3. | ``uuidv5("dns", "vnet.azure.com")`` to produce a completely predictable, reproducible UUID identifier token locked directly to a specific custom Azure private DNS domain namespace. |

---

## IP Network Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `cidrhost` | Calculates a full host IP address based on a host number within a specified CIDR prefix. | ``cidrhost("10.0.0.0/24", 4)`` to reliably identify the first usable IP address for custom devices inside an Azure subnet (since Azure permanently reserves network addresses `.0` through `.3`). |
| `cidrnetmask` | Converts an IPv4 address prefix given in CIDR notation into a subnet mask address. | ``cidrnetmask("10.1.0.0/16")`` to output `"255.255.0.0"`, providing the explicit dotted-decimal subnet mask value required by legacy firewall appliances hosted in Azure. |
| `cidrsubnet` | Calculates a single new subnet address extension within a given IP network prefix. | ``cidrsubnet("10.0.0.0/16", 8, 2)`` to carve out a clean, dedicated `/24` subnet layer specifically matching the architectural sizing rules required to deploy an Azure Bastion host. |
| `cidrsubnets` | Generates a sequence of consecutive, custom-sized IP address ranges within a parent block. | ``cidrsubnets("10.0.0.0/16", 8, 8, 4)`` to segment a main Azure VNet CIDR pool into two small `/24` subnet segments alongside a spacious `/20` backend subnet range all in a single call. |

---

## Type Conversion Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `can` | Evaluates an expression and returns a boolean indicating if it executed without errors. | ``can(regex("Standard", azurerm_linux_virtual_machine.vm.size))`` to return a simple true/false confirmation flag indicating if an active Azure VM size string matches a general compute specification profile. |
| `ephemeralasnull` | Intercepts an ephemeral lifecycle value and forces it to return null. | ``ephemeralasnull(var.azure_ephemeral_auth_token)`` to safely isolate and zero-out a temporary, short-lived Azure lifecycle authentication credential once a configuration block completes execution. |
| `issensitive` | Evaluates a value and returns true if it is currently flagged with a sensitive marker. | ``issensitive(azurerm_key_vault_secret.kv.value)`` to verify with a clear boolean result whether an output pulled from an Azure Key Vault secret resource is securely marked as sensitive. |
| `nonsensitive` | Removes sensitive output markings from a value, exposing it openly in the CLI. | ``nonsensitive(azurerm_public_ip.pip.ip_address)`` to strip away sensitive shielding markers from an Azure output, allowing the public IP to display openly in automation logs. |
| `sensitive` | Explicitly marks a value as sensitive so Terraform masks it in logs and CLI outputs. | ``sensitive(var.azure_sql_admin_password)`` to explicitly flag a SQL Server administrator credential password variable to prevent it from leaking into runtime terminal screens. |
| `tobool` | Forces conversion of a compatible argument value into an explicit boolean type. | ``tobool("true")`` to guarantee that a text configuration string input correctly transforms into a strict boolean flag required by an Azure disk caching configuration property. |
| `tolist` | Forces conversion of a compatible collection or value into an explicit list type. | ``tolist(azurerm_virtual_network.vnet.address_space)`` to cleanly transform a flexible set of VNet address prefixes into an ordered, indexed list structure. |
| `tomap` | Forces conversion of a compatible argument structure into an explicit map type. | ``tomap(var.azure_resource_tags)`` to convert an unstructured input object into a strict key-value map structure natively processed by the Azure resource tagging framework. |
| `tonumber` | Forces conversion of a compatible string or value into an explicit numeric type. | ``tonumber("443")`` to cast a text configuration property into an explicit numeric integer value to set up a destination firewall port inside an Azure NSG rule block. |
| `toset` | Forces conversion of a compatible list or collection into an explicit unique set type. | ``toset(["eastus", "westus", "eastus"])`` to clean up and deduplicate a messy configuration array into a unique, single-entry set structure (`["eastus", "westus"]`) for deploying regional Azure resources. |
| `tostring` | Forces conversion of a primitive value into an explicit string type. | ``tostring(azurerm_network_interface.nic.id)`` to guarantee that an explicit network card reference output converts cleanly into a flat text string data parameter. |
| `try` | Evaluates multiple expressions in sequence, returning the output of the first error-free one. | ``try(azurerm_subnet.sub.id, var.fallback_subnet_id)`` to attempt to capture a live, deployed Azure subnet resource ID string, falling back to a pre-set static string value if the primary resource fails to evaluate. |
| `type` | Dynamically evaluates and returns the exact type signature of a given value. | ``type(azurerm_resource_group.rg.tags)`` to run runtime syntax diagnostic checks to inspect the underlying map or object data signature model representing an Azure tagging block. |

---

## Terraform-Specific Functions

| Function | One-line Reminder | Azure Real-World Example |
| :--- | :--- | :--- |
| `provider::terraform::encode_tfvars` | Converts a structured object value into a valid `.tfvars` file syntax string. | ``provider::terraform::encode_tfvars({ azure_region = "eastus" })`` to serialize an active structural variable model into a clean, text-driven `.tfvars` configuration format string. |
| `provider::terraform::decode_tfvars` | Parses a raw `.tfvars` string format into a structured object map of variable values. | ``provider::terraform::decode_tfvars(file("azure_env.tfvars"))`` to read and parse an external environment variable block directly into live, native input configurations targeting Azure resources. |
| `provider::terraform::encode_expr` | Approximates a native value into a string containing Terraform language expression syntax. | ``provider::terraform::encode_expr(azurerm_resource_group.rg.tags)`` to extract the layout configuration model of an active Azure tagging setup and print it out directly as an expression string block. |