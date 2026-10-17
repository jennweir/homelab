resource "google_project_service" "cloud_resource_api" {
    project            = data.google_project.k8s_lab.project_id
    service            = "cloudresourcemanager.googleapis.com"
    disable_on_destroy = false
}

resource "google_project_service" "cloud_dns_api" {
    project            = data.google_project.k8s_lab.project_id
    service            = "dns.googleapis.com"
    disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
    project            = data.google_project.k8s_lab.project_id
    service            = "iam.googleapis.com"
    disable_on_destroy = false
}

resource "google_project_service" "secretmanager_api" {
    project            = data.google_project.k8s_lab.project_id
    service            = "secretmanager.googleapis.com"
    disable_on_destroy = false
}