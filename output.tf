output "lb-ip" {
    value = yandex_lb_network_load_balancer.balancer1.listener
}

output "vm-ips" {
    value = tomap({
      for name, site in yandex_compute_instance.site : name => site.network_interface.0.nat_ip_address  
    })
}