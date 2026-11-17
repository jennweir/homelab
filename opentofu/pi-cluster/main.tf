data "google_project" "pi_cluster" {
    project_id = "pi-cluster-433101"
}

resource "google_project_service" "wif" {
    project            = data.google_project.pi_cluster.project_id
    service            = "sts.googleapis.com"
    disable_on_destroy = false
}

locals {
    gh_pool = "gh-pool"
    gh_provider = "gh-provider"
}

resource "google_storage_bucket" "opentofu_backend" {
    project     = data.google_project.pi_cluster.project_id
    name        = "opentofu-backend-pi-cluster"
    location    = "US"
    force_destroy               = false
    public_access_prevention    = "enforced"
    uniform_bucket_level_access = true
    versioning {
        enabled = true
    }
}

resource "google_storage_bucket_iam_member" "gh_plan_backend" {
    for_each = toset([
        "roles/storage.objectViewer",
    ])
    bucket   = google_storage_bucket.opentofu_backend.name
    role     = each.value
    member   = "serviceAccount:${google_service_account.gh_plan.email}"
}

resource "google_project_iam_custom_role" "gh_plan_bucket_iam_editor" {
    project   = data.google_project.pi_cluster.project_id
    role_id   = "gh_plan_bucket_iam_editor"
    title     = "Bucket IAM Editor"
    description = "Least privilege role for editing bucket IAM policies"
    permissions = [
        "storage.buckets.getIamPolicy",
        "storage.buckets.setIamPolicy",
    ]
}

resource "google_project_iam_member" "gh_plan_bucket_iam_editor" {
    for_each = toset([
        google_service_account.gh_plan.account_id,
    ])
    project = data.google_project.pi_cluster.project_id
    role    = "projects/${data.google_project.pi_cluster.project_id}/roles/gh_plan_bucket_iam_editor"
    member  = "serviceAccount:${google_service_account.gh_plan.email}"
}

# GitHub Actions WIF pool and provider
resource "google_iam_workload_identity_pool" "gh_pool" {
    project                   = data.google_project.pi_cluster.project_id
    workload_identity_pool_id = local.gh_pool
    display_name              = local.gh_pool
    description               = "GitHub Actions workload identity pool"
}

resource "google_iam_workload_identity_pool_provider" "gh_provider" {
    project                            = data.google_project.pi_cluster.project_id
    display_name                       = local.gh_provider
    description                        = "GitHub Actions OIDC provider"
    workload_identity_pool_id          = google_iam_workload_identity_pool.gh_pool.workload_identity_pool_id
    workload_identity_pool_provider_id = local.gh_provider
    
    attribute_mapping = {
        "google.subject"             = "assertion.sub"
        "attribute.repository"       = "assertion.repository"
        "attribute.repository_owner" = "assertion.repository_owner"
    }

    attribute_condition = "assertion.repository_owner == 'jennweir'"

    oidc {
        issuer_uri        = "https://token.actions.githubusercontent.com"
    }
}

# Pipeline service accounts for GitHub Actions
resource "google_service_account" "gh_plan" {
    account_id   = "gh-plan"
    display_name = "CI/CD Plan Pipeline Service Account"
    project      = data.google_project.pi_cluster.project_id
}

resource "google_service_account" "gh_apply" {
    account_id   = "gh-apply"
    display_name = "CI/CD Apply Pipeline Service Account"
    project      = data.google_project.pi_cluster.project_id
}

resource "google_project_iam_member" "gh_plan_iam" {
    for_each = toset([
        "roles/viewer",
        "roles/storage.objectViewer",
    ])
    project = data.google_project.pi_cluster.project_id
    role    = each.value
    member  = "serviceAccount:${google_service_account.gh_plan.email}"
}

resource "google_project_iam_member" "gh_apply_iam" {
    for_each = toset([
        "roles/viewer",
        "roles/storage.objectViewer",
        "roles/storage.objectAdmin",
        "roles/resourcemanager.projectIamAdmin",
    ])
    project = data.google_project.pi_cluster.project_id
    role    = each.value
    member  = "serviceAccount:${google_service_account.gh_apply.email}"
}

resource "google_service_account_iam_member" "gh_plan_wif_binding" {
    service_account_id = google_service_account.gh_plan.name
    role               = "roles/iam.workloadIdentityUser"
    member             = "principalSet://iam.googleapis.com/projects/${data.google_project.pi_cluster.number}/locations/global/workloadIdentityPools/${local.gh_pool}/attribute.repository/jennweir/homelab"
}

resource "google_service_account_iam_member" "gh_apply_wif_binding" {
    service_account_id = google_service_account.gh_apply.name
    role               = "roles/iam.workloadIdentityUser"
    member             = "principal://iam.googleapis.com/projects/${data.google_project.pi_cluster.number}/locations/global/workloadIdentityPools/${local.gh_pool}/subject/repo:jennweir/homelab:ref:refs/heads/main"
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
