# # Output the IP address of the Load Balancer (if applicable)
# output "load_balancer_ip" {
#   description = "Public IP address of the Nginx Load Balancer"
#   value       = element(virtualbox_vm.lb.*.network_adapter.0.ipv4_address, 0)
# }

# # Output the IP addresses of the App Servers (Worker Nodes)
# output "app_server_ips" {
#   description = "List of IP addresses for the Flask application servers"
#   value       = virtualbox_vm.node.*.network_adapter.0.ipv4_address
# }

# # Output the application port
# output "app_port" {
#   description = "Port on which the Flask application listens"
#   value       = 5000
# }