/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { createServiceFactory, SpectatorService } from '@ngneat/spectator/jest';
import { provideMockActions } from '@ngrx/effects/testing';
import { Observable } from 'rxjs';
import { AuthApiService, UsersApiService } from '@taiga/api';
import { AppService } from '~/app/services/app.service';

import { AuthEffects } from './auth.effects';
import { Action } from '@ngrx/store';
import { login, loginSuccess, logout, setUser } from '../actions/auth.actions';
import { AuthMockFactory, UserMockFactory } from '@taiga/data';
import { randUserName, randPassword } from '@ngneat/falso';
import { cold, hot } from 'jest-marbles';
import { RouterTestingModule } from '@angular/router/testing';
import { Router } from '@angular/router';
import { AuthService } from '~/app/modules/auth/data-access/services/auth.service';

describe('AuthEffects', () => {
  let actions$: Observable<Action>;
  let spectator: SpectatorService<AuthEffects>;
  const createService = createServiceFactory({
    service: AuthEffects,
    providers: [provideMockActions(() => actions$)],
    imports: [RouterTestingModule],
    mocks: [AuthApiService, UsersApiService, Router, AppService, AuthService],
  });

  beforeEach(() => {
    spectator = createService();
  });

  it('login', () => {
    const loginData = {
      username: randUserName(),
      password: randPassword(),
    };
    const response = AuthMockFactory();
    const authApiService = spectator.inject(AuthApiService);
    const effects = spectator.inject(AuthEffects);

    authApiService.login.mockReturnValue(cold('-b|', { b: response }));

    actions$ = hot('-a', { a: login(loginData) });

    const expected = cold('--a', {
      a: loginSuccess({ auth: response, redirect: true }),
    });

    expect(effects.login$).toBeObservable(expected);
  });

  it('login success', () => {
    const user = UserMockFactory();
    const auth = AuthMockFactory();

    const effects = spectator.inject(AuthEffects);
    const authService = spectator.inject(AuthService);
    const routerService = spectator.inject(Router);
    const usersApiService = spectator.inject(UsersApiService);
    usersApiService.me.mockReturnValue(cold('-b|', { b: user }));

    actions$ = hot('-a', { a: loginSuccess({ auth, redirect: true }) });

    const expected = cold('--a', {
      a: setUser({ user }),
    });

    expect(effects.loginSuccess$).toBeObservable(expected);

    expect(effects.loginSuccess$).toSatisfyOnFlush(() => {
      expect(routerService.navigate).toHaveBeenCalledWith(['/']);
      expect(authService.setAuth).toHaveBeenCalledWith(auth);
    });
  });

  it('logout', () => {
    const effects = spectator.inject(AuthEffects);
    const authService = spectator.inject(AuthService);
    const routerService = spectator.inject(Router);

    actions$ = hot('-a', { a: logout() });

    expect(effects.logout$).toSatisfyOnFlush(() => {
      expect(authService.logout).toHaveBeenCalled();
      expect(routerService.navigate).toHaveBeenCalledWith(['/login']);
    });
  });

  it('set user', () => {
    const user = UserMockFactory();

    const effects = spectator.inject(AuthEffects);
    const authService = spectator.inject(AuthService);

    actions$ = hot('-a', { a: setUser({ user }) });

    expect(effects.setUser$).toSatisfyOnFlush(() => {
      expect(authService.setUser).toHaveBeenCalledWith(user);
    });
  });
});
