terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.134.0"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
}

data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "site" {
  count = 2
  name        = "site${count.index}" #Имя ВМ в облачной консоли
  hostname    = "site${count.index}" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!


  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data = file("./cloud-init.yml")
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet1.id
    nat                = true
  }
}

#создаем облачную сеть
resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet1" {
  name           = "subnet1"
  network_id     = yandex_vpc_network.network1.id
  v4_cidr_blocks = ["172.24.8.0/24"]
  zone           = "ru-central1-a"
}

resource "yandex_lb_target_group" "group1" {
  name = "group1"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet1.id
    address = yandex_compute_instance.site[0].network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet1.id
    address = yandex_compute_instance.site[1].network_interface.0.ip_address
  }

}

resource "yandex_lb_network_load_balancer" "balancer1" {
  name = "balancer1"
  deletion_protection = "false"
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.group1.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
