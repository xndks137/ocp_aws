output "bootstrap_role_arn" {
  description = "ARN of the bootstrap IAM role"
  value       = aws_iam_role.bootstrap.arn
}

output "bootstrap_instance_profile_name" {
  description = "Name of the bootstrap instance profile"
  value       = aws_iam_instance_profile.bootstrap.name
}

output "master_role_arn" {
  description = "ARN of the master IAM role"
  value       = aws_iam_role.master.arn
}

output "master_instance_profile_name" {
  description = "Name of the master instance profile"
  value       = aws_iam_instance_profile.master.name
}

output "worker_role_arn" {
  description = "ARN of the worker IAM role"
  value       = aws_iam_role.worker.arn
}

output "worker_instance_profile_name" {
  description = "Name of the worker instance profile"
  value       = aws_iam_instance_profile.worker.name
}
