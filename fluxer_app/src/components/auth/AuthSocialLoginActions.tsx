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

import {Trans} from '@lingui/react/macro';
import {AppleLogoIcon, GoogleLogoIcon} from '@phosphor-icons/react';
import {useEffect, useState} from 'react';
import * as AuthenticationActionCreators from '~/actions/AuthenticationActionCreators';
import type {SocialAuthProvider} from '~/actions/AuthenticationActionCreators';
import {Button} from '~/components/uikit/Button/Button';

export function AuthSocialLoginActions({
	className,
	disabled = false,
	redirectPath = '/',
}: {
	className?: string;
	disabled?: boolean;
	redirectPath?: string;
}) {
	const [providers, setProviders] = useState<Array<SocialAuthProvider>>([]);

	useEffect(() => {
		let mounted = true;
		void AuthenticationActionCreators.getSocialAuthProviders()
			.then((items) => {
				if (mounted) setProviders(items);
			})
			.catch(() => {
				if (mounted) setProviders([]);
			});

		return () => {
			mounted = false;
		};
	}, []);

	if (providers.length === 0) return null;

	return (
		<div className={className}>
			{providers.map((provider) => (
				<Button
					key={provider.id}
					type="button"
					fitContainer
					variant="secondary"
					disabled={disabled}
					leftIcon={provider.id === 'apple' ? <AppleLogoIcon size={16} /> : <GoogleLogoIcon size={16} />}
					onClick={() => AuthenticationActionCreators.startSocialAuth(provider.id, redirectPath)}
				>
					{provider.id === 'apple' ? <Trans>Continue with Apple</Trans> : <Trans>Continue with Google</Trans>}
				</Button>
			))}
		</div>
	);
}
