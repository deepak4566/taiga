/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { ChangeDetectionStrategy, Component, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { UntilDestroy, untilDestroyed } from '@ngneat/until-destroy';
import { Store } from '@ngrx/store';
import { RxState } from '@rx-angular/state';
import { Project, Workspace } from '@taiga/data';
import { ResizedEvent } from 'angular-resize-event';
import {
  selectWorkspace,
  selectWorkspaceProjects,
} from '~/app/modules/workspace/feature-detail/+state/selectors/workspace-detail.selectors';
import {
  fetchWorkspace,
  resetWorkspace,
} from '~/app/modules/workspace/feature-detail/+state/actions/workspace-detail.actions';
import { filterNil } from '~/app/shared/utils/operators';

@UntilDestroy()
@Component({
  selector: 'tg-workspace-detail',
  templateUrl: './workspace-detail.component.html',
  styleUrls: ['./workspace-detail.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [RxState],
})
export class WorkspaceDetailComponent implements OnInit {
  public readonly model$ = this.state.select();
  public amountOfProjectsToShow = 6;

  public get gridClass() {
    return `grid-items-${this.amountOfProjectsToShow}`;
  }

  constructor(
    private route: ActivatedRoute,
    private store: Store,
    private state: RxState<{
      projectsToShow: boolean;
      workspace: Workspace | null;
      project: Project[];
    }>
  ) {}

  public ngOnInit(): void {
    this.route.paramMap.pipe(untilDestroyed(this)).subscribe((params) => {
      const slug = params.get('slug');

      if (slug) {
        this.store.dispatch(fetchWorkspace({ slug }));
      }
    });

    this.state.connect(
      'workspace',
      this.store.select(selectWorkspace).pipe(filterNil())
    );
    this.state.connect('project', this.store.select(selectWorkspaceProjects));
  }

  public trackByLatestProject(index: number, project: Project) {
    return project.slug;
  }

  public setCardAmounts(width: number) {
    const amount = Math.ceil(width / 250);
    this.amountOfProjectsToShow = amount >= 6 ? 6 : amount;
  }

  public onResized(event: ResizedEvent) {
    this.setCardAmounts(event.newRect.width);
  }

  public ngOnDestroy() {
    this.store.dispatch(resetWorkspace());
  }
}
