@echo off
terraform apply -target="module.compute.google_compute_autoscaler.autoscaler[\"web-autoscaler\"]" -target="module.compute.google_compute_instance_group_manager.instance_group_manager[\"web-igm\"]" -auto-approve
