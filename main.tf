variable "name" {
  description = "The name of the bucket to create"
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

variable "lifecycle_prefix" {
  description = "Prefix with which to apply lifecycle rule (if enabled). Default value (empty string) applies to entire bucket https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-configuration-examples.html#lifecycle-config-ex1"
  default     = ""
}

variable "lifecycle_days" {
  description = "The number of days an object will have between creation and expiring, if lifecycle is enabled"
  default     = 30
}

resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.name
  acl    = "private"

  versioning {
    enabled = var.versioning
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
    enabled = var.lifecycle_enabled
    prefix  = var.lifecycle_prefix

    expiration {
      days = var.lifecycle_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  policy = data.aws_iam_policy_document.secure_bucket.json

  depends_on = [ aws_s3_bucket_public_access_block.secure_bucket ]
}

data "aws_iam_policy_document" "secure_bucket" {
  override_json = var.policy

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
      aws_s3_bucket.secure_bucket.arn,
      "${aws_s3_bucket.secure_bucket.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

output "bucket_arn" {
  description = "The ARN of the bucket created by this module"
  value       = aws_s3_bucket.secure_bucket.arn
}

output "bucket_name" {
  description = "The name of the bucket created by this module"
  value       = aws_s3_bucket.secure_bucket.bucket
}

