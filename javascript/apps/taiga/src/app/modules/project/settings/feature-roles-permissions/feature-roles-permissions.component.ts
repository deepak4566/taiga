/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import {
  AfterViewInit,
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  OnDestroy,
  OnInit,
} from '@angular/core';
import { FormBuilder, FormGroup } from '@angular/forms';
import { ActivatedRoute, NavigationEnd, Router } from '@angular/router';
import { UntilDestroy, untilDestroyed } from '@ngneat/until-destroy';
import { Store } from '@ngrx/store';
import { RxState, selectSlice } from '@rx-angular/state';
import { Project, Role } from '@taiga/data';
import { auditTime, filter, map, take } from 'rxjs/operators';
import {
  updateRolePermissions,
  updatePublicPermissions,
  updateWorkspacePermissions,
  resetPermissions,
  initRolesPermissions,
} from '~/app/modules/project/data-access/+state/actions/project.actions';
import {
  selectMemberRoles,
  selectCurrentProject,
  selectPublicPermissions,
  selectWorkspacePermissions,
} from '~/app/modules/project/data-access/+state/selectors/project.selectors';
import { filterNil } from '~/app/shared/utils/operators';
import { ModuleConflictPermission } from './models/modal-permission.model';
import { ProjectsSettingsFeatureRolesPermissionsService } from './services/feature-roles-permissions.service';

@UntilDestroy()
@Component({
  selector: 'tg-project-settings-feature-roles-permissions',
  templateUrl: './feature-roles-permissions.component.html',
  styleUrls: [
    './feature-roles-permissions.component.css',
    '../styles/settings.styles.css',
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [RxState],
})
export class ProjectSettingsFeatureRolesPermissionsComponent
  implements AfterViewInit, OnInit, OnDestroy
{
  public readonly model$ = this.state.select().pipe(
    map((model) => {
      const admin = model.memberRoles?.find((it) => it.isAdmin);

      return {
        ...model,
        admin,
      };
    })
  );
  public isModalOpen = false;

  public form = this.fb.group({});
  public publicForm = this.fb.group({});
  public workspaceForm = this.fb.group({});

  private readonly defaultFragment = 'member-permissions-settings';

  public get nativeElement() {
    return this.el.nativeElement as HTMLElement;
  }

  public getRoleForm(role: Role) {
    return this.form.get(role.slug) as FormGroup;
  }

  public getPublicPermissionsForm() {
    return this.publicForm.get('public') as FormGroup;
  }

  public getworkspacePermissionsForm() {
    return this.workspaceForm.get('workspace') as FormGroup;
  }

  constructor(
    private projectsSettingsFeatureRolesPermissionsService: ProjectsSettingsFeatureRolesPermissionsService,
    private el: ElementRef,
    private router: Router,
    private route: ActivatedRoute,
    private fb: FormBuilder,
    private store: Store,
    private state: RxState<{
      memberRoles?: Role[];
      publicPermissions?: string[];
      workspacePermissions?: string[];
      project: Project;
      conflicts: ModuleConflictPermission[];
    }>
  ) {}

  public ngOnInit() {
    this.state.set({ conflicts: [] });

    this.state.connect('project', this.store.select(selectCurrentProject));

    this.state.connect(
      'conflicts',
      this.state.select(selectSlice(['publicPermissions', 'memberRoles'])).pipe(
        map(({ publicPermissions, memberRoles }) => {
          return this.projectsSettingsFeatureRolesPermissionsService.getMembersPermissionsConflics(
            publicPermissions ?? [],
            memberRoles ?? []
          );
        })
      )
    );

    this.state.connect(
      'memberRoles',
      this.store.select(selectMemberRoles).pipe(filterNil())
    );

    this.state.connect(
      'publicPermissions',
      this.store.select(selectPublicPermissions).pipe(filterNil())
    );

    this.state.connect(
      'workspacePermissions',
      this.store.select(selectWorkspacePermissions).pipe(filterNil())
    );

    this.state.hold(this.state.select('project'), (project) => {
      this.store.dispatch(initRolesPermissions({ project }));
    });
  }

  public ngAfterViewInit() {
    this.watchFragment();
    this.initForm();
  }

  public initForm() {
    this.state.hold(
      this.state.select('memberRoles').pipe(take(1)),
      (roles = []) => {
        this.form = this.fb.group({});

        roles
          .filter((role) => !role.isAdmin)
          .forEach((role) => {
            this.createRoleFormControl(role.permissions, role.slug, this.form);
            this.watchRoleForm(role);
          });
      }
    );

    this.state.hold(
      this.state.select('publicPermissions').pipe(take(1)),
      (permissions = []) => {
        this.publicForm = this.fb.group({});
        this.createRoleFormControl(permissions, 'public', this.publicForm);
        this.watchPublicForm();
      }
    );

    this.state.hold(
      this.state.select('workspacePermissions').pipe(take(1)),
      (permissions = []) => {
        this.workspaceForm = this.fb.group({});
        this.createRoleFormControl(
          permissions,
          'workspace',
          this.workspaceForm
        );
        this.watchWorkspaceForm();
      }
    );
  }

  public watchRoleForm(role: Role) {
    const form = this.getRoleForm(role);

    form.valueChanges
      .pipe(untilDestroyed(this), auditTime(100))
      .subscribe(() => {
        this.saveMembers(role);
      });
  }

  public watchPublicForm() {
    this.publicForm.valueChanges
      .pipe(untilDestroyed(this), auditTime(100))
      .subscribe(() => {
        this.savePublic();
      });
  }

  public watchWorkspaceForm() {
    this.workspaceForm.valueChanges
      .pipe(untilDestroyed(this), auditTime(100))
      .subscribe(() => {
        this.saveWorkspace();
      });
  }

  public createRoleFormControl(
    permissions: string[],
    slug: string,
    form: FormGroup
  ) {
    const roleGroup = this.fb.group({});
    const currentPermissions =
      this.projectsSettingsFeatureRolesPermissionsService.formatRawPermissions(
        permissions
      );

    for (const [
      module,
    ] of this.projectsSettingsFeatureRolesPermissionsService.getModules()) {
      const fb = this.fb.group({
        create: [false],
        modify: [false],
        delete: [false],
        comment: [false],
      });

      if (
        !this.projectsSettingsFeatureRolesPermissionsService.hasComments(module)
      ) {
        fb.get('comment')?.disable();
      }

      roleGroup.addControl(module, fb);

      if (!currentPermissions[module]) {
        fb.disable();
      }
    }
    roleGroup.patchValue(currentPermissions);

    form.removeControl(slug);
    form.addControl(slug, roleGroup);
  }

  public saveMembers(role: Role) {
    const form = this.getRoleForm(role);

    const permissions =
      this.projectsSettingsFeatureRolesPermissionsService.getRoleFormGroupPermissions(
        form
      );

    this.store.dispatch(
      updateRolePermissions({
        project: this.state.get('project').slug,
        roleSlug: role.slug,
        permissions,
      })
    );
  }

  public savePublic() {
    const permissions =
      this.projectsSettingsFeatureRolesPermissionsService.getRoleFormGroupPermissions(
        this.getPublicPermissionsForm()
      );

    this.store.dispatch(
      updatePublicPermissions({
        project: this.state.get('project').slug,
        permissions,
      })
    );
  }

  public saveWorkspace() {
    const permissions =
      this.projectsSettingsFeatureRolesPermissionsService.getRoleFormGroupPermissions(
        this.getworkspacePermissionsForm()
      );

    this.store.dispatch(
      updateWorkspacePermissions({
        project: this.state.get('project').slug,
        permissions,
      })
    );
  }

  public watchFragment() {
    this.route.fragment.pipe(take(1)).subscribe((fragment) => {
      if (!fragment) {
        fragment = this.defaultFragment;
      }

      if (fragment !== this.defaultFragment) {
        this.focusFragment(fragment);
        void this.router.navigate([], {
          fragment: fragment,
        });
      }
    });

    this.router.events
      .pipe(
        filter((evt): evt is NavigationEnd => evt instanceof NavigationEnd),
        map((evt) => evt.url.split('#')[1])
      )
      .subscribe((fragment) => {
        const isInternal = this.router.getCurrentNavigation()?.extras.state
          ?.internal as boolean;

        if (!isInternal) {
          this.focusFragment(fragment);
        }
      });
  }

  public focusFragment(fragment: string) {
    const el = this.nativeElement.querySelector(
      `[data-fragment="${fragment}"] h3`
    );

    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
      (el as HTMLElement).focus({ preventScroll: true });
    }
  }

  public isInViewport(element: HTMLElement) {
    if (element.dataset.fragment) {
      this.changeFragment(element.dataset.fragment);
    }
  }

  public changeFragment(fragment: string) {
    void this.router.navigate([], {
      fragment: fragment,
      relativeTo: this.route,
      state: {
        internal: true,
      },
    });
  }

  public trackBySlug(_index: number, role: Role) {
    return role.slug;
  }

  public ngOnDestroy() {
    this.store.dispatch(resetPermissions());
  }

  public handleModal() {
    this.isModalOpen = !this.isModalOpen;
  }
}
