import { Link, type Href } from 'expo-router';
import type { ReactNode } from 'react';

type PlaceholderLinkProps = {
  href: Href;
  children: ReactNode;
  variant?: 'primary' | 'secondary';
};

const BASE_LINK_CLASS =
  'items-center rounded-2xl px-5 py-3 text-center font-body-semibold text-body';

const LINK_VARIANT_CLASS = {
  primary: 'bg-brand-primary text-white',
  secondary: 'border border-brand-primary text-brand-primary',
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
