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

import {useLingui} from '@lingui/react/macro';
import {observer} from 'mobx-react-lite';

export const FluxerSymbol = observer((props: React.SVGProps<SVGSVGElement>) => {
	const {t} = useLingui();

	return (
		<svg
			xmlns="http://www.w3.org/2000/svg"
			viewBox="0 0 512 512"
			role="img"
			aria-label={t`Atomic Radius application symbol`}
			{...props}
		>
			<circle cx={256} cy={256} r={28} fill="currentColor" />
			<ellipse cx={256} cy={256} fill="none" rx={180} ry={60} stroke="currentColor" strokeWidth={12} />
			<ellipse
				cx={256}
				cy={256}
				fill="none"
				rx={180}
				ry={60}
				stroke="currentColor"
				strokeWidth={12}
				transform="rotate(60 256 256)"
			/>
			<ellipse
				cx={256}
				cy={256}
				fill="none"
				rx={180}
				ry={60}
				stroke="currentColor"
				strokeWidth={12}
				transform="rotate(120 256 256)"
			/>
			<circle cx={76} cy={256} r={16} fill="currentColor" />
			<circle cx={346} cy={108} r={16} fill="currentColor" />
			<circle cx={346} cy={404} r={16} fill="currentColor" />
		</svg>
	);
});
