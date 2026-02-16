output "state_machine_arn" {
  description = "State machine arn"
  value = aws_sfn_state_machine.scatter_gather_service.arn
}