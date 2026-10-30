resource "google_project_service" "cloud_resource_api" {
    project            = data.google_project.pi_cluster.project_id
    service            = "cloudresourcemanager.googleapis.com"
    disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
    project            = data.google_project.pi_cluster.project_id
    service            = "iam.googleapis.com"
    disable_on_destroy = false
}

resource "google_project_service" "secretmanager_api" {
    project            = data.google_project.pi_cluster.project_id
    service            = "secretmanager.googleapis.com"
    disable_on_destroy = false
}