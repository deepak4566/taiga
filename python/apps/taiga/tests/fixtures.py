# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

import pytest
from taiga.main import api
from tests.utils.tasksqueue import TestTasksQueueManager
from tests.utils.testclient import TestClient


@pytest.fixture
def client() -> TestClient:
    return TestClient(api)


@pytest.fixture
def tqmanager() -> TestTasksQueueManager:
    return TestTasksQueueManager()
