/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# tfdoc:file:description IAM bindings.

locals {
  # expand any "$iam_role_sets:name" reference in a roles list to the set's constituent roles
  _iam_role_sets = {
    for k, v in var.context.iam_role_sets :
    "${local.ctx_p}iam_role_sets:${k}" => v
  }
  _expand_roles = {
    for k, v in var.iam : k => v
    if !startswith(k, "${local.ctx_p}iam_role_sets:")
  }
  # roles that are actually role-set references in var.iam keys
  _iam_from_role_sets = merge([
    for k, members in var.iam :
    {
      for role in lookup(local._iam_role_sets, k, []) :
      role => members
    }
    if startswith(k, "${local.ctx_p}iam_role_sets:")
  ]...)

  # expand role-set references in var.iam_by_principals role lists
  _iam_by_principals_expanded = {
    for principal, roles in var.iam_by_principals : principal => distinct(flatten([
      for role in roles :
      startswith(role, "${local.ctx_p}iam_role_sets:") ? lookup(local._iam_role_sets, role, [role]) : [role]
    ]))
  }

  _iam_principal_roles = distinct(flatten(values(local._iam_by_principals_expanded)))
  _iam_principals = {
    for r in local._iam_principal_roles : r => [
      for k, v in local._iam_by_principals_expanded :
      k if try(index(v, r), null) != null
    ]
  }
  ctx_iam_principals = merge(local.ctx.iam_principals, {
    "$iam_principalsets:service_accounts/all" = format(
      "principalSet://cloudresourcemanager.googleapis.com/folders/%s/type/ServiceAccount",
      coalesce(try(split("/", local.folder_id)[1], null), "-")
    )
  })
  iam = {
    for role in distinct(concat(keys(local._expand_roles), keys(local._iam_from_role_sets), keys(local._iam_principals))) :
    role => concat(
      try(local._expand_roles[role], []),
      try(local._iam_from_role_sets[role], []),
      try(local._iam_principals[role], [])
    )
  }
  iam_bindings_additive = merge(
    var.iam_bindings_additive,
    [
      for principal, roles in var.iam_by_principals_additive : {
        for role in roles :
        "iam-bpa:${principal}-${role}" => {
          member    = principal
          role      = role
          condition = null
        }
      }
    ]...
  )
  # convert all the iam_by_principals_conditional into a flat list of bindings
  _iam_bindings_conditional = flatten([
    for principal, config in var.iam_by_principals_conditional : [
      for role in config.roles : {
        principal = principal
        role      = role
        condition = config.condition
      }
    ]
  ])
  # group by (role, title)
  _iam_bindings_conditional_grouped = {
    for binding in local._iam_bindings_conditional :
    "iam-bpc:${binding.role}-${binding.condition.title}" => binding...
  }
  # finally we merge iam_bindings with the grouped conditional bindings
  iam_bindings = merge(
    var.iam_bindings,
    {
      for k, v in local._iam_bindings_conditional_grouped :
      k => {
        role      = v[0].role
        condition = v[0].condition
        members   = [for b in v : b.principal]
      }
    }
  )
}

resource "google_folder_iam_binding" "authoritative" {
  for_each = local.iam
  folder   = local.folder_id
  role     = lookup(local.ctx.custom_roles, each.key, each.key)
  members = [
    for v in each.value :
    lookup(local.ctx_iam_principals, v, v)
  ]
}

resource "google_folder_iam_binding" "bindings" {
  for_each = local.iam_bindings
  folder   = local.folder_id
  role     = lookup(local.ctx.custom_roles, each.value.role, each.value.role)
  members = [
    for v in each.value.members : lookup(local.ctx_iam_principals, v, v)
  ]
  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [""]
    content {
      expression = templatestring(
        each.value.condition.expression, var.context.condition_vars
      )
      title       = each.value.condition.title
      description = each.value.condition.description
    }
  }
}

resource "google_folder_iam_member" "bindings" {
  for_each = local.iam_bindings_additive
  folder   = local.folder_id
  role     = lookup(local.ctx.custom_roles, each.value.role, each.value.role)
  member = lookup(
    local.ctx.iam_principals, each.value.member, each.value.member
  )
  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [""]
    content {
      expression = templatestring(
        each.value.condition.expression, var.context.condition_vars
      )
      title       = each.value.condition.title
      description = each.value.condition.description
    }
  }
}
