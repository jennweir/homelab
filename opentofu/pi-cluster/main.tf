data "google_project" "pi_cluster" {
    project_id = "pi-cluster-433101"
}

resource "google_service_account" "gsm_accessor" {
    account_id   = "gsm-accessor"
    display_name = "GSM Accessor Service Account"
    project      = data.google_project.pi_cluster.project_id
}

resource "google_project_iam_member" "gsm_accessor_role" {
    project = data.google_project.pi_cluster.project_id
    role    = "roles/secretmanager.secretAccessor"
    member  = "serviceAccount:${google_service_account.gsm_accessor.email}"
}