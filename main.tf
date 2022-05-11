data "tfe_oauth_client" "ado" {
  oauth_client_id = var.ado_oauth_client_id
}

data "tfe_oauth_client" "github" {
  oauth_client_id = var.github_oauth_client_id
}

module "ado_repo" {
  source = "./ado_repo"
  org_name = var.ado_org_name
  team_name = var.team_name
  project_name = var.ado_project_name
  count = var.use_ado ? 1 : 0
}

module "github_repo" {
  source = "./github_repo"
  org_name = var.github_org_name
  team_name = var.team_name
  count = var.use_github ? 1 : 0
}



locals {
  # If GitHub get the GitHub modules repo_identifier
  # Else If ADO get the ADO modules repo_identifier 
  # Else ""
  vcs_identifier = var.use_github ? module.github_repo.0.repo_identifier : var.use_ado ? module.ado_repo.0.repo_identifier : ""

  # If GitHub get the GitHub OAuth token id
  # Else If ADO get the ADO OAuth token id
  # Else ""
  vcs_token_id = var.use_github ? data.tfe_oauth_client.github.oauth_token_id : var.use_ado ? data.tfe_oauth_client.ado.oauth_token_id : ""
}


resource "tfe_workspace" "team" {
    name         = "${var.team_name}-workspace"
    organization = var.org_name
    tag_names    = [var.team_name]

    vcs_repo {
      identifier = local.vcs_identifier
      oauth_token_id = local.vcs_token_id
    }

    count = local.vcs_identifier != "" && local.vcs_token_id != "" ? 1 : 0
}

resource "tfe_variable" "team_owner" {
  key          = "team_owner"
  value        = var.team_name
  category     = "terraform"
  workspace_id = tfe_workspace.team.0.id
  description  = "Name of the team workspace that created this workspace"
  sensitive    = false
}

resource "tfe_team" "team" {
  name         = "${var.team_name}"
  organization = var.org_name
}

resource "tfe_team_access" "team" {
  access       = "write"
  team_id      = tfe_team.team.id
  workspace_id = tfe_workspace.team.0.id
}