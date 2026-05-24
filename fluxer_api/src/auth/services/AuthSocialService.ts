/*
 * Copyright (C) 2026 Fluxer Contributors
 *
 * This file is part of Fluxer.
 *
 * Fluxer is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Fluxer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Fluxer. If not, see <https://www.gnu.org/licenses/>.
 */

import {createRemoteJWKSet, jwtVerify} from 'jose';
import type {RegisterRequest} from '~/auth/AuthModel';
import {createUserID} from '~/BrandedTypes';
import {APIErrorCodes} from '~/Constants';
import {Config} from '~/Config';
import {FluxerAPIError, InputValidationError} from '~/Errors';
import type {ICacheService} from '~/infrastructure/ICacheService';
import type {AuthSession, User} from '~/Models';
import type {RequestCache} from '~/middleware/RequestCacheMiddleware';
import type {IUserRepository} from '~/user/IUserRepository';
import {randomString} from '~/utils/RandomUtils';

type SocialProviderId = 'google' | 'apple';

interface ProviderConfig {
	id: SocialProviderId;
	label: string;
	issuer: string;
	authorizationEndpoint: string;
	tokenEndpoint: string;
	jwksUri: string;
	scopes: Array<string>;
	clientId?: string;
	clientSecret?: string;
}

interface SocialState {
	provider: SocialProviderId;
	redirectTo: string;
	nonce: string;
}

interface SocialIdentity {
	provider: SocialProviderId;
	providerUserId: string;
	email: string;
	emailVerified: boolean;
	name?: string;
}

interface SocialRegistrationTicket extends SocialIdentity {
	createdAt: string;
}

interface SocialTokenTicket {
	userId: string;
	token: string;
}

interface RegisterSocialParams {
	data: RegisterRequest & {social_ticket: string};
	request: Request;
	requestCache: RequestCache;
	register: (params: {data: RegisterRequest; request: Request; requestCache: RequestCache}) => Promise<{
		user_id: string;
		token: string;
		pending_verification?: boolean;
	}>;
}

const STATE_TTL_SECONDS = 10 * 60;
const TOKEN_TICKET_TTL_SECONDS = 2 * 60;
const REGISTRATION_TICKET_TTL_SECONDS = 15 * 60;
const SOCIAL_STATE_PREFIX = 'social-auth-state';
const SOCIAL_TOKEN_PREFIX = 'social-auth-token';
const SOCIAL_REGISTRATION_PREFIX = 'social-auth-register';

export class AuthSocialService {
	constructor(
		private repository: IUserRepository,
		private cacheService: ICacheService,
		private createAuthSession: (params: {user: User; request: Request}) => Promise<[string, AuthSession]>,
	) {}

	getEnabledProviders(): Array<{id: SocialProviderId; label: string}> {
		if (!Config.auth.social.enabled) return [];
		return this.getProviders()
			.filter((provider) => Boolean(provider.clientId && provider.clientSecret))
			.map(({id, label}) => ({id, label}));
	}

	async buildAuthorizationUrl(providerId: string, redirectTo: string): Promise<string> {
		const provider = this.requireProvider(providerId);
		const state = randomString(48);
		const nonce = randomString(32);

		await this.cacheService.set<SocialState>(
			`${SOCIAL_STATE_PREFIX}:${state}`,
			{provider: provider.id, redirectTo: this.normalizeRedirectTo(redirectTo), nonce},
			STATE_TTL_SECONDS,
		);

		const url = new URL(provider.authorizationEndpoint);
		url.searchParams.set('client_id', provider.clientId!);
		url.searchParams.set('redirect_uri', this.getRedirectUri(provider.id));
		url.searchParams.set('response_type', 'code');
		url.searchParams.set('scope', provider.scopes.join(' '));
		url.searchParams.set('state', state);
		url.searchParams.set('nonce', nonce);

		if (provider.id === 'apple') {
			url.searchParams.set('response_mode', 'form_post');
		}

		return url.toString();
	}

	async completeCallback(params: {providerId: string; code: string; state: string; request: Request}): Promise<string> {
		const provider = this.requireProvider(params.providerId);
		const state = await this.cacheService.getAndDelete<SocialState>(`${SOCIAL_STATE_PREFIX}:${params.state}`);
		if (!state || state.provider !== provider.id) {
			throw new FluxerAPIError({
				code: APIErrorCodes.INVALID_REQUEST,
				message: 'Invalid social login state',
				status: 400,
			});
		}

		const identity = await this.exchangeAndVerifyIdentity({provider, code: params.code, nonce: state.nonce});
		const existingUser = await this.repository.findByEmail(identity.email);
		if (existingUser) {
			const [token] = await this.createAuthSession({user: existingUser, request: params.request});
			const ticket = randomString(48);
			await this.cacheService.set<SocialTokenTicket>(
				`${SOCIAL_TOKEN_PREFIX}:${ticket}`,
				{token, userId: existingUser.id.toString()},
				TOKEN_TICKET_TTL_SECONDS,
			);
			return this.buildWebRedirect('/auth/social/callback', {ticket, redirect_to: state.redirectTo});
		}

		const registrationTicket = randomString(48);
		await this.cacheService.set<SocialRegistrationTicket>(
			`${SOCIAL_REGISTRATION_PREFIX}:${registrationTicket}`,
			{...identity, createdAt: new Date().toISOString()},
			REGISTRATION_TICKET_TTL_SECONDS,
		);

		return this.buildWebRedirect('/register', {social_ticket: registrationTicket, redirect_to: state.redirectTo});
	}

	async redeemTokenTicket(ticket: string): Promise<{token: string; user_id: string}> {
		const payload = await this.cacheService.getAndDelete<SocialTokenTicket>(`${SOCIAL_TOKEN_PREFIX}:${ticket}`);
		if (!payload) {
			throw InputValidationError.create('ticket', 'Invalid or expired social login ticket');
		}

		return {token: payload.token, user_id: payload.userId};
	}

	async getRegistrationTicket(ticket: string): Promise<{email: string; global_name?: string; provider: string}> {
		const payload = await this.cacheService.get<SocialRegistrationTicket>(`${SOCIAL_REGISTRATION_PREFIX}:${ticket}`);
		if (!payload) {
			throw InputValidationError.create('social_ticket', 'Invalid or expired social registration ticket');
		}

		return {email: payload.email, global_name: payload.name, provider: payload.provider};
	}

	async registerSocial({
		data,
		request,
		requestCache,
		register,
	}: RegisterSocialParams): Promise<{user_id: string; token: string; pending_verification?: boolean}> {
		const payload = await this.cacheService.getAndDelete<SocialRegistrationTicket>(
			`${SOCIAL_REGISTRATION_PREFIX}:${data.social_ticket}`,
		);
		if (!payload) {
			throw InputValidationError.create('social_ticket', 'Invalid or expired social registration ticket');
		}

		const {social_ticket: _socialTicket, ...registrationData} = data;
		const result = await register({
			data: {
				...registrationData,
				email: payload.email,
				global_name: data.global_name || payload.name,
				password: undefined,
			},
			request,
			requestCache,
		});

		if (payload.emailVerified) {
			await this.repository.patchUpsert(createUserID(BigInt(result.user_id)), {email_verified: true});
		}

		return result;
	}

	private async exchangeAndVerifyIdentity(params: {
		provider: ProviderConfig;
		code: string;
		nonce: string;
	}): Promise<SocialIdentity> {
		const {provider, code, nonce} = params;
		const tokenResponse = await fetch(provider.tokenEndpoint, {
			method: 'POST',
			headers: {'Content-Type': 'application/x-www-form-urlencoded'},
			body: new URLSearchParams({
				client_id: provider.clientId!,
				client_secret: provider.clientSecret!,
				code,
				grant_type: 'authorization_code',
				redirect_uri: this.getRedirectUri(provider.id),
			}),
		});

		const tokenBody = (await tokenResponse.json()) as {id_token?: string; error?: string; error_description?: string};
		if (!tokenResponse.ok || !tokenBody.id_token) {
			throw new FluxerAPIError({
				code: APIErrorCodes.INVALID_GRANT,
				message: tokenBody.error_description || tokenBody.error || 'Social login failed',
				status: 400,
			});
		}

		const jwks = createRemoteJWKSet(new URL(provider.jwksUri));
		const {payload} = await jwtVerify(tokenBody.id_token, jwks, {
			issuer: provider.issuer,
			audience: provider.clientId,
		});

		if (payload.nonce !== nonce) {
			throw new FluxerAPIError({code: APIErrorCodes.INVALID_TOKEN, message: 'Invalid social login nonce', status: 400});
		}

		const email = typeof payload.email === 'string' ? payload.email : null;
		if (!email) {
			throw new FluxerAPIError({
				code: APIErrorCodes.INVALID_REQUEST,
				message: 'The social provider did not return an email address',
				status: 400,
			});
		}

		return {
			provider: provider.id,
			providerUserId: String(payload.sub),
			email,
			emailVerified: payload.email_verified === true || payload.email_verified === 'true',
			name: typeof payload.name === 'string' ? payload.name : undefined,
		};
	}

	private requireProvider(providerId: string): ProviderConfig {
		const provider = this.getProviders().find((item) => item.id === providerId);
		if (!provider || !Config.auth.social.enabled || !provider.clientId || !provider.clientSecret) {
			throw new FluxerAPIError({
				code: APIErrorCodes.FEATURE_TEMPORARILY_DISABLED,
				message: 'This social login provider is not enabled',
				status: 404,
			});
		}
		return provider;
	}

	private getProviders(): Array<ProviderConfig> {
		return [
			{
				id: 'google',
				label: 'Google',
				issuer: 'https://accounts.google.com',
				authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
				tokenEndpoint: 'https://oauth2.googleapis.com/token',
				jwksUri: 'https://www.googleapis.com/oauth2/v3/certs',
				scopes: ['openid', 'email', 'profile'],
				clientId: Config.auth.social.google.clientId,
				clientSecret: Config.auth.social.google.clientSecret,
			},
			{
				id: 'apple',
				label: 'Apple',
				issuer: 'https://appleid.apple.com',
				authorizationEndpoint: 'https://appleid.apple.com/auth/authorize',
				tokenEndpoint: 'https://appleid.apple.com/auth/token',
				jwksUri: 'https://appleid.apple.com/auth/keys',
				scopes: ['openid', 'email', 'name'],
				clientId: Config.auth.social.apple.clientId,
				clientSecret: Config.auth.social.apple.clientSecret,
			},
		];
	}

	private getRedirectUri(providerId: SocialProviderId): string {
		return `${Config.endpoints.apiPublic.replace(/\/$/, '')}/auth/social/${providerId}/callback`;
	}

	private buildWebRedirect(path: string, params: Record<string, string>): string {
		const url = new URL(path, Config.endpoints.webApp);
		for (const [key, value] of Object.entries(params)) {
			url.searchParams.set(key, value);
		}
		return url.toString();
	}

	private normalizeRedirectTo(redirectTo: string): string {
		if (!redirectTo || !redirectTo.startsWith('/')) return '/';
		if (redirectTo.startsWith('//')) return '/';
		return redirectTo;
	}
}
