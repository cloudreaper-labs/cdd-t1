variable "resource_group_name" {
  type        = string
  description = "Your assigned resource group (set by the pipeline)."
}

variable "app_name" {
  type    = string
  default = "hello"
}

variable "image" {
  type    = string
  default = "docker.io/library/busybox:stable"
}

variable "greeting" {
  type        = string
  default     = "hello from v1"
  description = "Change me in a PR to watch the pipeline work."
}
