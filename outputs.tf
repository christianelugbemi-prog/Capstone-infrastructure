# Output the EC2 instance public IP for easy access
output "k3s_server_public_ip" {
  description = "Public IP address of the K3s EC2 instance"
  value       = aws_instance.k3s_server.public_ip
}

output "k3s_server_public_dns" {
  description = "Public DNS name of the K3s EC2 instance"
  value       = aws_instance.k3s_server.public_dns
}

# Output the SSH connection command
output "ssh_connection_command" {
  description = "Command to SSH into the K3s server"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.k3s_server.public_ip}"
}

# Output the web access URL
output "website_url" {
  description = "URL to access the deployed website"
  value       = "http://${aws_instance.k3s_server.public_ip}:30080"
}

# Output security group ID (for reference)
output "security_group_id" {
  description = "ID of the security group attached to K3s server"
  value       = aws_security_group.k3s_sg.id
}

# Output VPC information
output "vpc_id" {
  description = "ID of the VPC created"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnets[0]
}

# Output instance details
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.k3s_server.id
}

output "instance_type" {
  description = "Type of EC2 instance"
  value       = aws_instance.k3s_server.instance_type
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.k3s_server.availability_zone
}