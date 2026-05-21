parent = "organizations/12345678"
name   = "folder-a"

context = {
  iam_role_sets = {
    viewer_plus = ["roles/viewer", "roles/browser"]
    editor_plus = ["roles/editor", "roles/viewer", "roles/browser"]
  }
  iam_principals = {
    myuser = "user:user@example.com"
    mysa   = "serviceAccount:sa@project.iam.gserviceaccount.com"
  }
}

# iam: role sets in the key (role position) - single role set expands to multiple bindings
iam = {
  "$iam_role_sets:viewer_plus" = ["$iam_principals:myuser"]
}

# iam_by_principals: role sets in the values (roles list for a principal)
iam_by_principals = {
  "$iam_principals:mysa" = ["$iam_role_sets:viewer_plus"]
}
