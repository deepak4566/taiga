/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { randNumber, randSlug, randStatus } from '@ngneat/falso';
import { Status } from './status.model';

export const StatusMockFactory = (): Status => {
  return {
    name: randStatus(),
    slug: randSlug(),
    color: randNumber({
      max: 2,
    }),
  };
};
