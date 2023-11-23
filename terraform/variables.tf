# Define where the source will be copied to
data "google_storage_bucket" "functions_src" {
  name = "functions-src-1b149"
}
variable "project_id" {
  type        = string
  default     = "mybots-397304"
  
}
variable "region" {
  type        = string
  default     = "us-west1"
  
}
variable "function_base_name" {
  type        = string
  default     = "kasa-h300-hydrop"
  
}
variable "function_h300" {
  type        = string
  default     = "kasa-h300-hydrop"
  
}
