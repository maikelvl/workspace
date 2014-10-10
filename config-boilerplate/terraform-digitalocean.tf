
provider "digitalocean" {
	token = "${var.do_token}"
}

# Create a web droplet
resource "digitalocean_droplet" "coreos" {
	image = "coreos"
	name = "coreos-01"
	region = "${var.default_region}"
	size = "1gb"
	ipv6 = true
	private_networking = true
	ssh_keys = [your-ssh-key-id-here]
	# provisioner "file" {
	#     source = "provision"
	#     destination = "/provision"
	#     connection {
	# 		key_file = "${var.pvt_key}"
	# 	}
	# }

	# provisioner "remote-exec" {
	# 	inline = [
	# 		"apt-get update",
	# 		"bash /provision/provision install/docker",
	# 		"touch /hello-world.txt"
	# 	]
	# 	connection {
	# 		key_file = "${var.pvt_key}"
	# 	}
	# }
}
