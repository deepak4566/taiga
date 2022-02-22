/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import {
  ChangeDetectorRef,
  Directive,
  Input,
  OnInit,
  TemplateRef,
  ViewContainerRef,
} from '@angular/core';
import { UntilDestroy, untilDestroyed } from '@ngneat/until-destroy';
import { Entity, EntityPermission } from '@taiga/data';
import { PermissionsService } from '~/app/services/permissions.service';

// How to use

// Append this directive to any HTML with conditions:
// Permission to test (view, edit, etc.)
// Entity to apply the permission (issue, task, etc.)
// Operation you want to perform between the permissions query (AND | OR)

// Example
// <div *hasPermission="['comment']; entity: 'issue'; operation: 'OR'"> Visible </div>

// If the conditions are met, the content will be visible, otherwise this node will be removed from the HTML.

export type Operation = 'AND' | 'OR';

@UntilDestroy()
// eslint-disable-next-line @angular-eslint/directive-selector
@Directive({ selector: '[hasPermission]' })
export class HasPermissionDirective implements OnInit {
  @Input()
  public set hasPermission(permission: EntityPermission[]) {
    this.permissions = Array.isArray(permission) ? permission : [permission];
  }

  @Input()
  public set hasPermissionEntity(entity: Entity | Entity[]) {
    this.entities = Array.isArray(entity) ? entity : [entity];
  }

  @Input()
  public set hasPermissionOperation(operation: Operation) {
    this.operation = operation;
  }

  private hasView = false;
  private operation: 'AND' | 'OR' = 'AND';
  private permissions: EntityPermission[] = [];
  private entities!: Entity[];

  constructor(
    private permissionsService: PermissionsService,
    private templateRef: TemplateRef<unknown>,
    private viewContainer: ViewContainerRef,
    private cd: ChangeDetectorRef
  ) {}

  public ngOnInit() {
    this.permissionsService
      .hasPermissions$(this.entities, this.permissions, this.operation)
      .pipe(untilDestroyed(this))
      .subscribe((view) => {
        this.updateView(view);
      });
  }

  private updateView(view: boolean) {
    if (view && !this.hasView) {
      this.hasView = true;
      this.viewContainer.createEmbeddedView(this.templateRef);
      this.cd.markForCheck();
    } else {
      this.viewContainer.clear();
      this.hasView = false;
    }
  }
}
