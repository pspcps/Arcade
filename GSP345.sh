#!/bin/bash

clear

# Prompt for values
echo "Enter the BUCKET name:"
read BUCKET
export BUCKET

echo "Enter the INSTANCE name:"
read INSTANCE
export INSTANCE

echo "Enter the VPC name:"
read VPC
export VPC

# Get Zone, Region, and Project ID
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)
export PROJECT_ID=$DEVSHELL_PROJECT_ID

# Get Instance IDs
instances_output=$(gcloud compute instances list --format="value(id)")
IFS=$'\n' read -r -d '' instance_id_1 instance_id_2 <<< "$instances_output"
export INSTANCE_ID_1=$instance_id_1
export INSTANCE_ID_2=$instance_id_2

# Create Terraform folders and files
mkdir -p modules/instances modules/storage
touch main.tf variables.tf
touch modules/instances/{instances.tf,outputs.tf,variables.tf}
touch modules/storage/{storage.tf,outputs.tf,variables.tf}

# Write Terraform variable definitions
cat > variables.tf <<EOF
variable "region" {
  default = "$REGION"
}

variable "zone" {
  default = "$ZONE"
}

variable "project_id" {
  default = "$PROJECT_ID"
}
EOF

# Initial provider configuration
cat > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.53.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "instances" {
  source = "./modules/instances"
}
EOF

terraform init

# Instance module - basic version
cat > modules/instances/instances.tf <<EOF
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "n1-standard-1"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
  }
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "n1-standard-1"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
  }
  allow_stopping_for_update = true
}
EOF

# Import existing instances
terraform import module.instances.google_compute_instance.tf-instance-1 $INSTANCE_ID_1
terraform import module.instances.google_compute_instance.tf-instance-2 $INSTANCE_ID_2

terraform plan
terraform apply -auto-approve

# Create storage bucket module
cat > modules/storage/storage.tf <<EOF
resource "google_storage_bucket" "storage-bucket" {
  name                        = "$BUCKET"
  location                    = "us"
  force_destroy               = true
  uniform_bucket_level_access = true
}
EOF

# Add storage module to main.tf
cat >> main.tf <<EOF
module "storage" {
  source = "./modules/storage"
}
EOF

terraform init
terraform apply -auto-approve

# Switch to GCS backend
cat > main.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "$BUCKET"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.53.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "instances" {
  source = "./modules/instances"
}

module "storage" {
  source = "./modules/storage"
}
EOF

terraform init

# Rebuild instance module with custom machine type
cat > modules/instances/instances.tf <<EOF
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
  }
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
  }
  allow_stopping_for_update = true
}

resource "google_compute_instance" "$INSTANCE" {
  name         = "$INSTANCE"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
  }
  allow_stopping_for_update = true
}
EOF

terraform init
terraform apply -auto-approve

terraform taint module.instances.google_compute_instance.$INSTANCE
terraform init
terraform plan
terraform apply -auto-approve

# VPC module (using official module)
cat >> main.tf <<EOF
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 6.0.0"

  project_id   = "$PROJECT_ID"
  network_name = "$VPC"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = "subnet-01"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = "$REGION"
    },
    {
      subnet_name           = "subnet-02"
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = "$REGION"
      subnet_private_access = true
      subnet_flow_logs      = true
      description           = "Hola"
    }
  ]
}
EOF

terraform init
terraform plan
terraform apply -auto-approve

# Attach VPC subnet to instances
cat > modules/instances/instances.tf <<EOF
resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = "$VPC"
    subnetwork = "subnet-01"
  }
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  machine_type = "e2-standard-2"
  zone         = "$ZONE"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = "$VPC"
    subnetwork = "subnet-02"
  }
  allow_stopping_for_update = true
}
EOF

terraform init
terraform plan
terraform apply -auto-approve

# Add firewall rule
cat >> main.tf <<EOF
resource "google_compute_firewall" "tf-firewall" {
  name    = "tf-firewall"
  network = "projects/$PROJECT_ID/global/networks/$VPC"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_tags   = ["web"]
  source_ranges = ["0.0.0.0/0"]
}
EOF

terraform init
terraform plan
terraform apply -auto-approve

# Completion message
echo "Terraform deployment complete."
