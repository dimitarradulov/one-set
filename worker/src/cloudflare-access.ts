import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';

export interface AccessConfiguration {
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUDIENCE: string;
  ACCESS_APPROVED_EMAIL: string;
}

const keySets = new Map<string, JWTVerifyGetKey>();

function keySet(teamDomain: string): JWTVerifyGetKey {
  let keys = keySets.get(teamDomain);
  if (!keys) {
    keys = createRemoteJWKSet(new URL(`${teamDomain.replace(/\/$/, '')}/cdn-cgi/access/certs`));
    keySets.set(teamDomain, keys);
  }
  return keys;
}

export async function verifyCloudflareAccess(
  request: Request,
  configuration: AccessConfiguration,
  controlledKeySource?: JWTVerifyGetKey,
): Promise<boolean> {
  const token = request.headers.get('Cf-Access-Jwt-Assertion')
    ?? request.headers.get('Cookie')?.split(';').map(value => value.trim())
      .find(value => value.startsWith('CF_Authorization='))?.slice('CF_Authorization='.length);
  if (!token || !configuration.ACCESS_TEAM_DOMAIN || !configuration.ACCESS_AUDIENCE
      || !configuration.ACCESS_APPROVED_EMAIL) return false;

  try {
    const { payload } = await jwtVerify(token, controlledKeySource ?? keySet(configuration.ACCESS_TEAM_DOMAIN), {
      issuer: configuration.ACCESS_TEAM_DOMAIN.replace(/\/$/, ''),
      audience: configuration.ACCESS_AUDIENCE,
      clockTolerance: 0,
    });
    return typeof payload.exp === 'number' && typeof payload.email === 'string'
      && payload.email.toLowerCase() === configuration.ACCESS_APPROVED_EMAIL.toLowerCase();
  } catch {
    return false;
  }
}
