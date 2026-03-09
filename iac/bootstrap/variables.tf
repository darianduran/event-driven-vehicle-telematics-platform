variable "app" {
  description = "The name of the app"
  type        = string
  default     = ""
}

variable "env" {
  description = "The environment to deploy to"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = ""
}