provider "digitalocean" {
  version = "~> 1.6"
  token   = "${var.do_token}"
}

resource "digitalocean_volume" "main" {
  name   = "${terraform.workspace}-main"
  region = "sfo2"
  size   = 1
}

# This ssh key may exist if you are managing multiple workspaces. To import this value, you
# should use the API, see: https://developers.digitalocean.com/documentation/v2/#ssh-keys
resource "digitalocean_ssh_key" "main" {
  name       = "${var.do_ssh_key_name}"
  public_key = file("/root/.ssh/id_rsa.pub")
}

resource "digitalocean_droplet" "main" {
  name     = "${terraform.workspace}-main"
  image    = "ubuntu-18-04-x64"
  region   = "sfo2"
  size     = "s-1vcpu-1gb"
  ssh_keys = ["${digitalocean_ssh_key.main.fingerprint}"]
}

resource "digitalocean_volume_attachment" "main" {
  droplet_id = "${digitalocean_droplet.main.id}"
  volume_id  = "${digitalocean_volume.main.id}"

  # Ensure that we can connect to the droplet via ssh before running ansible.
  provisioner "remote-exec" {
    inline = ["true"]
    connection {
      type        = "ssh"
      user        = "root"
      host        = "${digitalocean_droplet.main.ipv4_address}"
      private_key = "${file("/root/.ssh/id_rsa")}"
    }
  }

  provisioner "local-exec" {
    # Extra comma in inventory is necessary for inventory (comma separated list)
    # ansible_python_interpretor is necessary because of Ubuntu Xenial: https://github.com/ansible/ansible/issues/19605
    command = "ansible-playbook --inventory '${digitalocean_droplet.main.ipv4_address},' -e 'ansible_python_interpreter=/usr/bin/python3' -e 'terraform_workspace=${terraform.workspace}' ../playbooks/main.yml"
  }
}

resource "digitalocean_project" "project" {
  name        = "${terraform.workspace}-tweeter"
  environment = "Development"
  resources   = [digitalocean_droplet.main.urn, digitalocean_volume.main.urn]
}

provider "cloudflare" {
  version   = "~> 2.0"
  api_token = "${var.cf_token}"
}

# Requires a zone to exist in the Cloudflare account named `var.cf_zone`.
# This zone is not managed by terraform because we share it between workspaces.
data "cloudflare_zones" "main" {
  filter {
    name   = "${var.cf_zone}"
    status = "active"
    paused = false
  }
}

resource "cloudflare_record" "main" {
  zone_id = "${lookup(data.cloudflare_zones.main.zones[0], "id")}"
  name    = "${terraform.workspace}"
  value   = "${digitalocean_droplet.main.ipv4_address}"
  type    = "A"
}
