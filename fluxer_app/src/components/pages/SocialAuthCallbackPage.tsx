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
import {useEffect, useState} from 'react';
import * as AuthenticationActionCreators from '~/actions/AuthenticationActionCreators';
import {AuthErrorState} from '~/components/auth/AuthErrorState';
import {AuthLoadingState} from '~/components/auth/AuthLoadingState';
import {useFluxerDocumentTitle} from '~/hooks/useFluxerDocumentTitle';
import {useLocation} from '~/lib/router';
import {Routes} from '~/Routes';
import * as RouterUtils from '~/utils/RouterUtils';

export default function SocialAuthCallbackPage() {
	useFluxerDocumentTitle('Signing in');
	const location = useLocation();
	const [error, setError] = useState<string | null>(null);

	useEffect(() => {
		const params = new URLSearchParams(location.search);
		const ticket = params.get('ticket');
		const redirectTo = params.get('redirect_to') || Routes.ME;

		if (!ticket) {
			setError('Missing social login ticket');
			return;
		}

		void AuthenticationActionCreators.redeemSocialAuthTicket(ticket)
			.then(async (response) => {
				await AuthenticationActionCreators.completeLogin({token: response.token, userId: response.user_id});
				RouterUtils.replaceWith(redirectTo);
			})
			.catch(() => setError('That social login link expired. Please try again.'));
	}, [location.search]);

	if (error) {
		return <AuthErrorState title={<Trans>Sign in failed</Trans>} text={error} />;
	}

	return <AuthLoadingState />;
}
