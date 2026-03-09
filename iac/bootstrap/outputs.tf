output "bootstrap-backend" {
  description = "Bootstrap config"
  value       = <<-EOT
        backend "s3" {
            bucket = "${aws_s3_bucket.state-bucket.id}"
            key = "terraform.tfstate"
            region = "${var.aws_region}"
            dynamodb_table = "${aws_dynamodb_table.tfstate-lock.id}"
            encrypt = true
        }
    EOT
}