# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL
from taiga.base.serializers import BaseModel
from taiga.projects.projects.serializers.related import ProjectSummarySerializer


class WorkspaceDetailSerializer(BaseModel):
    name: str
    slug: str
    color: int
    latest_projects: list[ProjectSummarySerializer]
    invited_projects: list[ProjectSummarySerializer]
    total_projects: int
    has_projects: bool
    is_premium: bool
    user_role: str
    user_is_owner: bool

    class Config:
        orm_mode = True


class WorkspaceSerializer(BaseModel):
    name: str
    slug: str
    color: int
    is_premium: bool
    total_projects: int
    has_projects: bool
    user_role: str
    user_is_owner: bool

    class Config:
        orm_mode = True
