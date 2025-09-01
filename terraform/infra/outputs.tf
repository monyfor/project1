output "instance_id" { value = aws_instance.vm.id }
output "public_ip" { value = aws_eip.vm.public_ip }
output "sg_id" { value = aws_security_group.vm.id }