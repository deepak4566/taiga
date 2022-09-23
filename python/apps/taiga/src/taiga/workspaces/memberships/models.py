# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL


from taiga.base.db import models


class WorkspaceMembership(models.BaseModel):
    user = models.ForeignKey(
        "users.User",
        null=False,
        blank=False,
        related_name="workspace_memberships",
        on_delete=models.CASCADE,
        verbose_name="user",
    )
    workspace = models.ForeignKey(
        "workspaces.Workspace",
        null=False,
        blank=False,
        related_name="memberships",
        on_delete=models.CASCADE,
        verbose_name="workspace",
    )
    role = models.ForeignKey(
        "workspaces_roles.WorkspaceRole",
        null=False,
        blank=False,
        related_name="memberships",
        on_delete=models.CASCADE,
        verbose_name="role",
    )
    created_at = models.DateTimeField(null=False, blank=False, auto_now_add=True, verbose_name="created at")

    class Meta:
        verbose_name = "workspace membership"
        verbose_name_plural = "workspace memberships"
        unique_together = (
            "user",
            "workspace",
        )
        ordering = ["workspace", "user"]

    def __str__(self) -> str:
        return f"{self.workspace} - {self.user}"

    def __repr__(self) -> str:
        return f"<WorkspaceMembership {self.workspace} {self.user}>"
