# Google ------------------------------------------------------------------------------------------------------------------

locals {
    wif_pool = "k8s-pool"
    wif_provider = "k8s-provider"
    avp_gsm_secrets = [
        "azure_client_id",
        "azure_issuer_url",
        "azure_client_secret"
    ]
    argocd_eso_secrets = [
        "quay-jennweir-pull-secret"
    ]
}

resource "google_dns_managed_zone" "homelab_zone" {
    project     = "coreos-k8s-lab"
    name        = "homelab-zone"
    dns_name    = "homelab.jenniferpweir.com."
    description = "Homelab subdomain zone delegated to cloud DNS"
}

data "google_project" "k8s_lab" {
    project_id = "coreos-k8s-lab"
}

resource "google_project_service" "wif" {
    project            = data.google_project.k8s_lab.project_id
    service            = "sts.googleapis.com"
    disable_on_destroy = false
}

resource "google_storage_bucket" "homelab_bucket" {
    project = data.google_project.k8s_lab.project_id
    name = "jennweir-homelab-oidc"
    location = "US"
    force_destroy = true
    public_access_prevention = "inherited"
    uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "homelab_bucket" {
    bucket = google_storage_bucket.homelab_bucket.name
    role   = "roles/storage.objectViewer"
    member = "allUsers"
}

resource "google_iam_workload_identity_pool" "k8s_pool" {
    project                   = data.google_project.k8s_lab.project_id
    workload_identity_pool_id = local.wif_pool
    display_name              = local.wif_pool
    description               = "created with terraform"
}

resource "google_iam_workload_identity_pool_provider" "k8s_provider" {
    project = data.google_project.k8s_lab.project_id
    display_name                       = local.wif_provider
    description                        = "created with terraform"
    workload_identity_pool_id          = google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id
    workload_identity_pool_provider_id = local.wif_provider
    attribute_mapping = {
        "google.subject" = "assertion.sub"
    }
    oidc {
        issuer_uri        = "https://storage.googleapis.com/jennweir-homelab-oidc"
        allowed_audiences = [
            "//iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/providers/${local.wif_provider}", 
        ]
    }
}

# resource "google_service_account" "test_gsm_accessor" {
#     account_id   = "test-gsm-accessor"
#     display_name = "GSM Accessor Service Account for Testing"
#     project      = data.google_project.k8s_lab.project_id
# }

# resource "google_secret_manager_secret_iam_member" "test_secret_access" {
#     project   = data.google_project.k8s_lab.project_id
#     secret_id = "test-secret"
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "serviceAccount:${google_service_account.test_gsm_accessor.email}"
# }

# resource "google_service_account_iam_member" "smoke_tests_wif_binding" {
#     service_account_id = "projects/${data.google_project.k8s_lab.project_id}/serviceAccounts/${google_service_account.test_gsm_accessor.email}"
#     role               = "roles/iam.workloadIdentityUser"
#     member             = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:smoke-tests:smoke-tests-sa"
# }

# resource "google_service_account" "gsm_accessor" {
#     account_id   = "gsm-accessor"
#     display_name = "GSM Accessor Service Account"
#     project      = data.google_project.k8s_lab.project_id
# }

# resource "google_secret_manager_secret_iam_member" "gsm_secret_access" {
#     for_each  = toset(local.avp_gsm_secrets)

#     project   = data.google_project.k8s_lab.project_id
#     secret_id = each.value
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "serviceAccount:${google_service_account.gsm_accessor.email}"
# }

# resource "google_service_account_iam_member" "argocd_wif_binding" {
#     service_account_id = "projects/${data.google_project.k8s_lab.project_id}/serviceAccounts/${google_service_account.gsm_accessor.email}"
#     role               = "roles/iam.workloadIdentityUser"
#     member             = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:argocd:argocd-argocd-repo-server"
# }

resource "google_service_account" "cert_manager_dns_solver" {
    account_id   = "cert-manager-dns-solver"
    display_name = "Cert Manager dns01 Solver Service Account"
    project      = data.google_project.k8s_lab.project_id
}

resource "google_project_iam_custom_role" "cert_manager_dns_solver_role" {
    role_id     = "cert_manager_dns_solver_role"
    title       = "Cert Manager DNS Role"
    description = "Least privilege role for cert-manager to manage Cloud DNS"
    project     = data.google_project.k8s_lab.project_id
    permissions = [
        "dns.resourceRecordSets.create",
        "dns.resourceRecordSets.delete",
        "dns.resourceRecordSets.get",
        "dns.resourceRecordSets.list",
        "dns.resourceRecordSets.update",
        "dns.changes.create",
        "dns.changes.get",
        "dns.changes.list",
        "dns.managedZones.list",
    ]
}

resource "google_project_iam_member" "cert_manager_dns_solver_role_binding" {
    project = data.google_project.k8s_lab.project_id
    role    = "projects/${data.google_project.k8s_lab.project_id}/roles/${google_project_iam_custom_role.cert_manager_dns_solver_role.role_id}"
    member  = "serviceAccount:${google_service_account.cert_manager_dns_solver.email}"
}

resource "google_service_account_iam_member" "cert_manager_wif_binding" {
    service_account_id = "projects/${data.google_project.k8s_lab.project_id}/serviceAccounts/${google_service_account.cert_manager_dns_solver.email}"
    role               = "roles/iam.workloadIdentityUser"
    member             = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:cert-manager:cert-manager"
}

# make k8s service account secretAccessor directly instead of via impersonation of google service account bc of eso limitations
# resource "google_secret_manager_secret_iam_member" "openshift_monitoring_secret_accessor" {
#     project   = data.google_project.k8s_lab.project_id
#     secret_id = "alertmanager-discord-config"
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:openshift-monitoring:external-secrets"
# }

# # make k8s service account secretAccessor directly instead of via impersonation of google service account bc of eso limitations
# resource "google_secret_manager_secret_iam_member" "argocd_eso_secret_access" {
#     for_each  = toset(local.argocd_eso_secrets)

#     project   = data.google_project.k8s_lab.project_id
#     secret_id = each.value
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:argocd:external-secrets"
# }

# argocd SA access to Azure AD secrets
# resource "google_secret_manager_secret_iam_member" "argocd_azure_tenant_id_accessor" {
#     project   = data.google_project.k8s_lab.project_id
#     secret_id = "azure_tenant_id"
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:argocd:argocd-argocd-repo-server"
# }

# resource "google_secret_manager_secret_iam_member" "argocd_azure_client_id_accessor" {
#     project   = data.google_project.k8s_lab.project_id
#     secret_id = "azure_client_id"
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:argocd:argocd-argocd-repo-server"
# }

# resource "google_secret_manager_secret_iam_member" "argocd_azure_client_secret_accessor" {
#     project   = data.google_project.k8s_lab.project_id
#     secret_id = "azure_client_secret"
#     role      = "roles/secretmanager.secretAccessor"
#     member    = "principal://iam.googleapis.com/projects/${data.google_project.k8s_lab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k8s_pool.workload_identity_pool_id}/subject/system:serviceaccount:argocd:argocd-argocd-repo-server"
# }

# Azure ------------------------------------------------------------------------------------------------------------------

resource "azuread_application" "okd_cluster" {
    display_name = "okd-cluster"
    web {
        redirect_uris = [
            "https://oauth-openshift.apps.okd.jenniferpweir.com/oauth2callback/Azure_AD",
            "https://console-openshift-console.apps.okd.jenniferpweir.com/auth/callback",
            "https://argocd-server-argocd.apps.okd.jenniferpweir.com/auth/callback"
        ]
    }
}
