context = {
  iam_role_sets = {
    viewer_plus = ["roles/viewer", "roles/browser"]
  }
  iam_principals = {
    myuser = "user:user@example.com"
    mysa   = "serviceAccount:sa@project.iam.gserviceaccount.com"
  }
}

# var.iam: role set as a map key, expands to one authoritative binding per role
iam = {
  "$iam_role_sets:viewer_plus" = ["$iam_principals:myuser"]
}

# var.iam_by_principals: role set in the roles list, merged into authoritative bindings
iam_by_principals = {
  "$iam_principals:mysa" = ["$iam_role_sets:viewer_plus"]
}

# var.iam_by_principals_additive: role set in the roles list, one additive member binding per role
iam_by_principals_additive = {
  "$iam_principals:myuser" = ["$iam_role_sets:viewer_plus"]
}

# var.iam_by_principals_conditional: role set in the roles list, one conditional binding per role
iam_by_principals_conditional = {
  "$iam_principals:mysa" = {
    roles = ["$iam_role_sets:viewer_plus"]
    condition = {
      title      = "expires_soon"
      expression = "request.time < timestamp(\"2027-01-01T00:00:00Z\")"
    }
  }
}
