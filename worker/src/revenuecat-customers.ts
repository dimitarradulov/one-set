const REVENUECAT_API = 'https://api.revenuecat.com/v2/projects';
const REQUEST_TIMEOUT_MS = 5000;

export type RevenueCatCustomerResult =
  | { status: 'deleted' }
  | { status: 'notFound' }
  | { status: 'temporaryFailure'; httpStatus?: number };

export interface RevenueCatConfiguration {
  REVENUECAT_PROJECT_ID: string;
  REVENUECAT_SECRET_KEY: string;
}

// Requests deletion of the RevenueCat customer whose App User ID is the Clerk user ID.
// RevenueCat queues the deletion; a 404 means the customer is already gone or never existed.
export async function deleteCustomer(
  customerId: string,
  config: RevenueCatConfiguration,
  fetcher: typeof fetch = fetch,
): Promise<RevenueCatCustomerResult> {
  if (!config.REVENUECAT_PROJECT_ID || !config.REVENUECAT_SECRET_KEY) return { status: 'temporaryFailure' };
  const url = `${REVENUECAT_API}/${encodeURIComponent(config.REVENUECAT_PROJECT_ID)}/customers/${encodeURIComponent(customerId)}`;
  try {
    const response = await fetcher(url, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${config.REVENUECAT_SECRET_KEY}` },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    // Release the connection; the body is not needed.
    await response.body?.cancel();
    if (response.ok) return { status: 'deleted' };
    if (response.status === 404) return { status: 'notFound' };
    return { status: 'temporaryFailure', httpStatus: response.status };
  } catch {
    return { status: 'temporaryFailure' };
  }
}
