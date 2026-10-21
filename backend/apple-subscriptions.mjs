import { Buffer } from 'node:buffer';

const products = new Set(['com.gindausd.max.pro.monthly', 'com.gindausd.max.pro.yearly']);
export class SubscriptionUnavailable extends Error {}

// No client flags, decoded JWTs, or user metadata grant paid access.
/** @param {{env?: Record<string, string | undefined>, now?: () => number, loadLibrary?: () => Promise<any>}} options */
export function createAppleSubscriptionVerifier({ env = process.env, now = Date.now, loadLibrary } = {}) {
  let setup;
  return async function verifyPaid(signedTransaction, userID) {
    if (typeof signedTransaction !== 'string' || !signedTransaction || signedTransaction.length > 16000) return null;
    if (!setup) {
      setup = (async () => {
        const { APPLE_IAP_KEY_ID: keyID, APPLE_IAP_ISSUER_ID: issuerID, APPLE_IAP_PRIVATE_KEY: privateKey,
          APPLE_ROOT_CERTIFICATES_BASE64: rootsJSON, APPLE_APP_ID: appID } = env;
        const environment = env.APPLE_STORE_ENVIRONMENT || 'Production';
        if (!keyID || !issuerID || !privateKey || !rootsJSON || !['Production', 'Sandbox'].includes(environment)
            || (environment === 'Production' && !/^[1-9]\d*$/.test(appID || ''))) throw new SubscriptionUnavailable();
        const roots = JSON.parse(rootsJSON);
        if (!Array.isArray(roots) || roots.length === 0 || roots.some(root => typeof root !== 'string' || !root)) throw new SubscriptionUnavailable();
        const library = await (loadLibrary ? loadLibrary() : import(
          typeof Deno !== 'undefined' ? 'npm:@apple/app-store-server-library@3.1.0' : '@apple/app-store-server-library'
        ));
        const bundleID = 'com.gindausd.max';
        return {
          verifier: new library.SignedDataVerifier(roots.map(root => Buffer.from(root, 'base64')), true, environment, bundleID, appID ? Number(appID) : undefined),
          client: new library.AppStoreServerAPIClient(privateKey.replaceAll('\\n', '\n'), keyID, issuerID, bundleID, environment),
        };
      })().catch(() => { setup = undefined; throw new SubscriptionUnavailable(); });
    }
    const { verifier, client } = await setup;
    let proof;
    try { proof = await verifier.verifyAndDecodeTransaction(signedTransaction); }
    catch { return null; }
    const owned = tx => typeof tx?.appAccountToken === 'string'
      && tx.appAccountToken.toLowerCase() === userID.toLowerCase()
      && tx.bundleId === 'com.gindausd.max' && products.has(tx.productId)
      && tx.type === 'Auto-Renewable Subscription' && !tx.revocationDate
      && Number.isFinite(tx.expiresDate) && tx.expiresDate > now();
    if (!owned(proof) || !proof.originalTransactionId) return null;
    // Ask Apple for current status: an old, unexpired JWS alone cannot prove
    // that a subscription has not since been refunded or revoked.
    let status;
    try { status = await client.getAllSubscriptionStatuses(proof.originalTransactionId); }
    catch { throw new SubscriptionUnavailable(); }
    for (const group of status.data || []) {
      for (const item of group.lastTransactions || []) {
        if (item.status !== 1 || typeof item.signedTransactionInfo !== 'string') continue;
        let current;
        try { current = await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo); }
        catch { continue; }
        if (owned(current) && current.originalTransactionId === proof.originalTransactionId) {
          return { active: true, productID: current.productId, expiresAt: new Date(current.expiresDate).toISOString() };
        }
      }
    }
    return null;
  };
}
