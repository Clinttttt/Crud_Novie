/**
 * The client never hardcodes the .NET port. It calls "/api/..." and the Angular dev
 * server forwards those calls to the API (see proxy.conf.json), which also keeps the
 * browser from complaining about cross-origin requests.
 */
export const environment = { apiUrl: '/api' };
