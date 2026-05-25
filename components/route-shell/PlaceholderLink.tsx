import { Link, type Href } from 'expo-router';
import type { ReactNode } from 'react';

import { BASE_LINK_CLASS, LINK_VARIANT_CLASS } from '@/constants/placeholder-link';

type PlaceholderLinkProps = {
  href: Href;
  children: ReactNode;
  variant?: 'primary' | 'secondary';
};

export default function PlaceholderLink({
  href,
  children,
  variant = 'primary',
}: PlaceholderLinkProps) {
  return (
    <Link className={`${BASE_LINK_CLASS} ${LINK_VARIANT_CLASS[variant]}`} href={href}>
      {children}
    </Link>
  );
}
