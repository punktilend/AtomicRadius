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

import {Trans, useLingui} from '@lingui/react/macro';
import {observer} from 'mobx-react-lite';
import {useEffect, useState} from 'react';
import * as AuthenticationActionCreators from '~/actions/AuthenticationActionCreators';
import {AuthBottomLink} from '~/components/auth/AuthBottomLink';
import {AuthLoginDivider} from '~/components/auth/AuthLoginCore/AuthLoginPasskeyActions';
import sharedStyles from '~/components/auth/AuthPageStyles.module.css';
import {AuthRegisterFormCore} from '~/components/auth/AuthRegisterFormCore';
import {AuthSocialLoginActions} from '~/components/auth/AuthSocialLoginActions';
import {useFluxerDocumentTitle} from '~/hooks/useFluxerDocumentTitle';
import {useLocation} from '~/lib/router';

const RegisterPageContent = observer(function RegisterPageContent() {
	const location = useLocation();
	const params = new URLSearchParams(location.search);
	const rawRedirect = params.get('redirect_to');
	const redirectTo = rawRedirect || '/';
	const socialTicket = params.get('social_ticket');
	const [socialInfo, setSocialInfo] = useState<{email: string; global_name?: string; provider: string} | null>(null);

	useEffect(() => {
		if (!socialTicket) {
			setSocialInfo(null);
			return;
		}

		void AuthenticationActionCreators.getSocialRegistrationTicket(socialTicket)
			.then(setSocialInfo)
			.catch(() => setSocialInfo(null));
	}, [socialTicket]);

	return (
		<>
			<h1 className={sharedStyles.title}>
				<Trans>Create an account</Trans>
			</h1>

			<div className={sharedStyles.container}>
				<AuthRegisterFormCore
					fields={{
						showEmail: !socialTicket,
						showPassword: !socialTicket,
						showDisplayName: true,
						showUsername: false,
						showUsernameValidation: false,
						showBetaCode: false,
						showBetaCodeHint: false,
						requireBetaCode: false,
					}}
					submitLabel={<Trans>Create account</Trans>}
					redirectPath={redirectTo}
					socialTicket={socialTicket}
					initialGlobalName={socialInfo?.global_name}
					extraContent={
						socialInfo ? (
							<div className={sharedStyles.notice}>
								<Trans>Using {socialInfo.email}</Trans>
							</div>
						) : null
					}
				/>

				{!socialTicket ? (
					<AuthSocialLoginActions
						className={sharedStyles.socialActionsCompact}
						redirectPath={redirectTo}
						leadingContent={
							<AuthLoginDivider
								classes={{
									divider: sharedStyles.divider,
									dividerLine: sharedStyles.dividerLine,
									dividerText: sharedStyles.dividerText,
								}}
							/>
						}
					/>
				) : null}

				<AuthBottomLink
					variant="login"
					to={`/login${rawRedirect ? `?redirect_to=${encodeURIComponent(rawRedirect)}` : ''}`}
				/>
			</div>
		</>
	);
});

const RegisterPage = observer(function RegisterPage() {
	const {t} = useLingui();
	useFluxerDocumentTitle(t`Register`);

	return <RegisterPageContent />;
});

export default RegisterPage;
