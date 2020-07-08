variable "name" {
  description = "The name of the bucket to create"
}

variable "region" {
  description = "The region in which to create the bucket"
}

variable "versioning" {
  description = "Whether or not to enable versioning"
  default     = false
}

variable "policy" {
  description = "A policy to merge with the default bucket policy that requires SSL"
  default     = ""
}

variable "lifecycle_enabled" {
  description = "Whether or not a expiring object lifecycle is enabled for the bucket"
  default     = false
}

variable "lifecycle_days" {
  description = "The number of days an object will have between creation and expiring, if lifecycle is enabled"
  default     = 30
}

resource "aws_s3_bucket" "secure_bucket" {
  region = "${var.region}"

  bucket = "${var.name}"
  acl    = "private"

  versioning {
    enabled = "${var.versioning}"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "default-expiry"
    enabled = "${var.lifecycle_enabled}"

    expiration {
      days = "${var.lifecycle_days}"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket = "${aws_s3_bucket.secure_bucket.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "secure_bucket" {
  override_json = "${var.policy}"

  statement {
    sid = "AllowSSLRequestsOnly"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    effect = "Deny"

    actions = [
      "s3:*",
    ]

    resources = [
      "${aws_s3_bucket.secure_bucket.arn}",
      "${aws_s3_bucket.secure_bucket.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "secure_bucket" {
  bucket = "${aws_s3_bucket.secure_bucket.id}"

  policy = "${data.aws_iam_policy_document.secure_bucket.json}"
}

output "bucket_arn" {
  description = "The ARN of the bucket created by this module"
  value       = "${aws_s3_bucket.secure_bucket.arn}"
}

output "bucket_name" {
  description = "The name of the bucket created by this module"
  value       = "${aws_s3_bucket.secure_bucket.bucket}"
}