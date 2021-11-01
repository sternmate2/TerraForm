
resource "null_resource" remoteExecProvisionerWFolder {

  provisioner "file" {
    source      = "/home/shahars/ShaharTF/test2.txt"
    destination = "/home/shahars/.ssh/test.txt"
  }
  connection {
    bastion_host = "13.90.255.58" 
    host         = "80.0.0.4"
    user         = "shahars"
    private_key  = "${file("~/.ssh/id_rsa")}"
  }

}

