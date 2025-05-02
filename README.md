# Kinesis-producer-demo


Base Blob: Active, current version of a blob.

Snapshot: A point-in-time, read-only copy of the base blob.

Versioning: Automatically keeps track of every modification to the blob and provides access to earlier versions.


| **Feature**     | **Base Blob**                                      | **Snapshot**                                           | **Versioning**                                                            |
|----------------|-----------------------------------------------------|--------------------------------------------------------|---------------------------------------------------------------------------|
| **Purpose**     | Active, current version of the blob                 | Read-only copy of the blob at a specific time          | Tracks and stores every change to the blob                                |
| **Modification**| Can be modified directly                            | Cannot be modified after creation                      | Automatically created when the base blob is modified                      |
| **Use Cases**   | General data storage, active files                  | Backup, restore points                                 | Automatic version history, revert changes                                |
| **Storage**     | Regular storage                                     | Shares storage with the base blob                      | Separate storage per version, independent of base blob                   |
| **Access**      | Read/write operations                               | Read-only operations                                   | Read/write operations for the latest version; can access previous versions |
| **Deletion**    | Can be deleted                                      | Can be deleted independently of the base blob          | Can delete individual versions                                            |


| **Field**                                   | **Description**                                                   | **Constraints / Notes**                                                                 |
|--------------------------------------------|-------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| `storage_account_id`                       | ID of the target storage account                                  | **Required**                                                                             |
| `name` (in rule)                           | Name of the lifecycle rule                                        | **Required**                                                                             |
| `enabled`                                  | Enable or disable the rule                                        | **Required (Boolean)**                                                                   |
| `prefix_match`                             | Blob name prefixes to match                                       | Optional; can be used with `match_blob_index_tag`                                        |
| `blob_types`                               | Types of blobs (e.g., `blockBlob`)                                | **Required**                                                                             |
| `match_blob_index_tag`                     | Tag-based filters                                                 | Optional; supports `name`, `operation`, and `value`                                      |
| `tier_to_cool_after_days_*`                | Tier blob to cool                                                 | Only one allowed per rule                                                                |
| `tier_to_archive_after_days_*`             | Tier blob to archive                                              | Only one allowed per rule                                                                |
| `tier_to_cold_after_days_*`                | Tier blob to cold                                                 | Only one allowed per rule                                                                |
| `delete_after_days_*`                      | Delete blob                                                       | Only one allowed per rule; requires `last_access_time_enabled` if using access-based     |
| `auto_tier_to_hot_from_cool_enabled`       | Auto rehydrate to hot tier if accessed                            | Must be used with `tier_to_cool_after_days_since_last_access_time_greater_than`         |
| `last_access_time_enabled` (Storage Account setting) | Enable last access tracking                           | Required to use any `*_last_access_time_*` fields                                        |



Known issues and limitations
Tiering is not yet supported in a premium block blob storage account. For all other accounts, tiering is allowed only on block blobs and not for append and page blobs.

A lifecycle management policy must be read or written in full. Partial updates are not supported.

Each rule can have up to 10 case-sensitive prefixes and up to 10 blob index tag conditions.

A lifecycle management policy can't be used to change the tier of a blob that uses an encryption scope to the archive tier.

The delete action of a lifecycle management policy won't work with any blob in an immutable container. With an immutable policy, objects can be created and read, but not modified or deleted. For more information, see Store business-critical blob data with immutable storage.



Azure Storage Lifecycle Management Policy - Full Reference

This page explains the configuration options available in the azurerm_storage_management_policy resource in Terraform. It includes field usage, constraints, and examples to aid your configuration.

✅ Top-Level Block

azurerm_storage_management_policy

storage_account_id (Required): The ID of the storage account this policy is applied to.

📦 rule Block

Each rule defines lifecycle actions for a set of blobs.

name (Required): Name of the lifecycle rule.

enabled (Required): Boolean to enable or disable the rule.

🔍 filters

Defines which blobs this rule applies to.

prefix_match (Optional): List of blob name prefixes.

blob_types (Required): Types of blobs targeted: blockBlob, appendBlob, pageBlob.

match_blob_index_tag (Optional):

name: Tag key.

operation: Comparison operator (e.g., ==).

value: Tag value.

📌 prefix_match and match_blob_index_tag can be used together.

⚙️ actions Block

Specifies actions taken on matched blobs.

📂 base_blob

Used for the main version of the blob.

Cool Tiering

tier_to_cool_after_days_since_modification_greater_than: Moves blobs to cool tier after last modification.

tier_to_cool_after_days_since_last_access_time_greater_than: Moves blobs to cool tier after last access. Requires last_access_time_enabled = true.

tier_to_cool_after_days_since_creation_greater_than: Moves blobs to cool tier after creation.

auto_tier_to_hot_from_cool_enabled: Automatically moves blob back to hot tier if accessed after moved to cool.

❗ Only one of the tier_to_cool_* fields can be set.
❗ auto_tier_to_hot_from_cool_enabled must be used with tier_to_cool_after_days_since_last_access_time_greater_than.

Archive Tiering

tier_to_archive_after_days_since_modification_greater_than: Moves blobs to archive after last modification.

tier_to_archive_after_days_since_last_access_time_greater_than: Moves blobs to archive after last access.

tier_to_archive_after_days_since_creation_greater_than: Moves blobs to archive after creation.

tier_to_archive_after_days_since_last_tier_change_greater_than: Archives blob after last tier change.

❗ Only one of the tier_to_archive_* fields can be set.

Cold Tiering

tier_to_cold_after_days_since_modification_greater_than: Moves blobs to cold tier after modification.

tier_to_cold_after_days_since_last_access_time_greater_than: Moves blobs to cold tier after last access.

tier_to_cold_after_days_since_creation_greater_than: Moves blobs to cold tier after creation.

❗ Only one of the tier_to_cold_* fields can be set.

Deletion

delete_after_days_since_modification_greater_than: Deletes blob after last modification.

delete_after_days_since_last_access_time_greater_than: Deletes blob after last access.

delete_after_days_since_creation_greater_than: Deletes blob after creation.

❗ Only one of the delete_after_* fields can be set.
❗ For any *_last_access_time_* field, last_access_time_enabled = true must be set in the Storage Account.

🧩 Example for base_blob

base_blob {
  tier_to_cool_after_days_since_modification_greater_than = 10
  tier_to_archive_after_days_since_modification_greater_than = 50
  delete_after_days_since_modification_greater_than = 100
}

🧪 snapshot

Applies actions to blob snapshots.

change_tier_to_archive_after_days_since_creation: Tiers snapshot to archive after creation.

change_tier_to_cool_after_days_since_creation: Tiers snapshot to cool after creation.

tier_to_archive_after_days_since_last_tier_change_greater_than: Archives snapshot after last tier change.

tier_to_cold_after_days_since_creation_greater_than: Moves snapshot to cold tier after creation.

delete_after_days_since_creation_greater_than: Deletes snapshot after creation.

📌 Example

snapshot {
  change_tier_to_archive_after_days_since_creation = 90
  change_tier_to_cool_after_days_since_creation = 23
  delete_after_days_since_creation_greater_than = 31
}

🧬 version

Applies actions to blob versions.

change_tier_to_archive_after_days_since_creation: Tiers version to archive after creation.

change_tier_to_cool_after_days_since_creation: Tiers version to cool after creation.

tier_to_archive_after_days_since_last_tier_change_greater_than: Archives version after last tier change.

tier_to_cold_after_days_since_creation_greater_than: Moves version to cold tier after creation.

delete_after_days_since_creation: Deletes version after creation.

📌 Example

version {
  change_tier_to_archive_after_days_since_creation = 9
  change_tier_to_cool_after_days_since_creation = 90
  delete_after_days_since_creation = 3
}

🧠 Understanding Blob Types

Base Blob: Main content of a blob.

Snapshot: Read-only version of a blob taken at a point in time.

Version: Similar to snapshot, but versioning is automatically managed by Azure if enabled.

❗ Lifecycle rules apply separately to each of these types.

💡 Example Terraform Policy

resource "azurerm_storage_management_policy" "example" {
  storage_account_id = azurerm_storage_account.example.id

  rule {
    name    = "rule1"
    enabled = true
    filters {
      prefix_match = ["container1/prefix1"]
      blob_types   = ["blockBlob"]
      match_blob_index_tag {
        name      = "tag1"
        operation = "=="
        value     = "val1"
      }
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 10
        tier_to_archive_after_days_since_modification_greater_than = 50
        delete_after_days_since_modification_greater_than          = 100
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }
    }
  }

  rule {
    name    = "rule2"
    enabled = false
    filters {
      prefix_match = ["container2/prefix1", "container2/prefix2"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 11
        tier_to_archive_after_days_since_modification_greater_than = 51
        delete_after_days_since_modification_greater_than          = 101
      }
      snapshot {
        change_tier_to_archive_after_days_since_creation = 90
        change_tier_to_cool_after_days_since_creation    = 23
        delete_after_days_since_creation_greater_than    = 31
      }
      version {
        change_tier_to_archive_after_days_since_creation = 9
        change_tier_to_cool_after_days_since_creation    = 90
        delete_after_days_since_creation                 = 3
      }
    }
  }
}

Let me know if you’d like this as a downloadable PDF or Confluence import format.


🧱 Step 1: Create variables.tf
Define a variable that can hold multiple rules:

hcl
Copy
Edit
variable "lifecycle_rules" {
  description = "List of lifecycle management rules for blob storage"
  type = list(object({
    name    = string
    enabled = bool
    prefix_match = list(string)
    blob_types   = list(string)
    match_blob_index_tag = optional(object({
      name      = string
      operation = string
      value     = string
    }))
    actions = object({
      base_blob = optional(object({
        tier_to_cool_after_days    = optional(number)
        tier_to_archive_after_days = optional(number)
        delete_after_days          = optional(number)
      }))
      snapshot = optional(object({
        change_tier_to_archive_after_days = optional(number)
        change_tier_to_cool_after_days    = optional(number)
        delete_after_days                 = optional(number)
        delete_after_days_since_creation_greater_than = optional(number)
      }))
      version = optional(object({
        change_tier_to_archive_after_days = optional(number)
        change_tier_to_cool_after_days    = optional(number)
        delete_after_days                 = optional(number)
      }))
    })
  }))
}
🧪 Step 2: Add Sample terraform.tfvars
hcl
Copy
Edit
lifecycle_rules = [
  {
    name    = "rule1"
    enabled = true
    prefix_match = ["container1/prefix1"]
    blob_types   = ["blockBlob"]
    match_blob_index_tag = {
      name      = "tag1"
      operation = "=="
      value     = "val1"
    }
    actions = {
      base_blob = {
        tier_to_cool_after_days    = 10
        tier_to_archive_after_days = 50
        delete_after_days          = 100
      }
      snapshot = {
        delete_after_days_since_creation_greater_than = 30
      }
    }
  },
  {
    name    = "rule2"
    enabled = false
    prefix_match = ["container2/prefix1", "container2/prefix2"]
    blob_types   = ["blockBlob"]
    actions = {
      base_blob = {
        tier_to_cool_after_days    = 11
        tier_to_archive_after_days = 51
        delete_after_days          = 101
      }
      snapshot = {
        change_tier_to_archive_after_days = 90
        change_tier_to_cool_after_days    = 23
        delete_after_days                 = 31
      }
      version = {
        change_tier_to_archive_after_days = 9
        change_tier_to_cool_after_days    = 90
        delete_after_days                 = 3
      }
    }
  }
]
🔁 Step 3: Create the Resource Using dynamic "rule" (Main Code)
hcl
Copy
Edit
resource "azurerm_storage_management_policy" "example" {
  storage_account_id = azurerm_storage_account.example.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      name    = rule.value.name
      enabled = rule.value.enabled

      filters {
        prefix_match = rule.value.prefix_match
        blob_types   = rule.value.blob_types

        dynamic "match_blob_index_tag" {
          for_each = rule.value.match_blob_index_tag != null ? [rule.value.match_blob_index_tag] : []
          content {
            name      = match_blob_index_tag.value.name
            operation = match_blob_index_tag.value.operation
            value     = match_blob_index_tag.value.value
          }
        }
      }

      actions {
        dynamic "base_blob" {
          for_each = rule.value.actions.base_blob != null ? [rule.value.actions.base_blob] : []
          content {
            tier_to_cool_after_days_since_modification_greater_than    = lookup(base_blob.value, "tier_to_cool_after_days", null)
            tier_to_archive_after_days_since_modification_greater_than = lookup(base_blob.value, "tier_to_archive_after_days", null)
            delete_after_days_since_modification_greater_than          = lookup(base_blob.value, "delete_after_days", null)
          }
        }

        dynamic "snapshot" {
          for_each = rule.value.actions.snapshot != null ? [rule.value.actions.snapshot] : []
          content {
            change_tier_to_archive_after_days_since_creation = lookup(snapshot.value, "change_tier_to_archive_after_days", null)
            change_tier_to_cool_after_days_since_creation    = lookup(snapshot.value, "change_tier_to_cool_after_days", null)
            delete_after_days_since_creation_greater_than    = lookup(snapshot.value, "delete_after_days_since_creation_greater_than", null)
            delete_after_days                                 = lookup(snapshot.value, "delete_after_days", null)
          }
        }

        dynamic "version" {
          for_each = rule.value.actions.version != null ? [rule.value.actions.version] : []
          content {
            change_tier_to_archive_after_days_since_creation = lookup(version.value, "change_tier_to_archive_after_days", null)
            change_tier_to_cool_after_days_since_creation    = lookup(version.value, "change_tier_to_cool_after_days", null)
            delete_after_days                                 = lookup(version.value, "delete_after_days", null)
          }
        }
      }
    }
  }
}
