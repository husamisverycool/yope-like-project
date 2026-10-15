// JSON Web Tokens signed with node:crypto: ES256 for APNs provider tokens, RS256 for the Google
// OAuth 2.0 JWT bearer grant (FCM service account).

import crypto from "node:crypto";

const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");

/** ES256 (P-256 / SHA-256), signature as raw r||s (JWS), from a PKCS#8 .p8 key. */
export function signEs256(header: Record<string, unknown>, claims: Record<string, unknown>, pem: string): string {
  const input = `${b64({ alg: "ES256", ...header })}.${b64(claims)}`;
  const sig = crypto.sign("sha256", Buffer.from(input), { key: pem, dsaEncoding: "ieee-p1363" });
  return `${input}.${sig.toString("base64url")}`;
}

/** RS256 (RSASSA-PKCS1-v1_5 / SHA-256). */
export function signRs256(header: Record<string, unknown>, claims: Record<string, unknown>, pem: string): string {
  const input = `${b64({ alg: "RS256", typ: "JWT", ...header })}.${b64(claims)}`;
  const sig = crypto.sign("sha256", Buffer.from(input), pem);
  return `${input}.${sig.toString("base64url")}`;
}

export function decodeJwt(jwt: string): { header: Record<string, unknown>; claims: Record<string, unknown>; signature: Buffer } {
  const [h, c, s] = jwt.split(".");
  if (!h || !c || !s) throw new Error("malformed JWT");
  return {
    header: JSON.parse(Buffer.from(h, "base64url").toString("utf8")),
    claims: JSON.parse(Buffer.from(c, "base64url").toString("utf8")),
    signature: Buffer.from(s, "base64url"),
  };
}

export function verifyEs256(jwt: string, publicKey: crypto.KeyLike): boolean {
  const i = jwt.lastIndexOf(".");
  return crypto.verify("sha256", Buffer.from(jwt.slice(0, i)), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(jwt.slice(i + 1), "base64url"));
}

export function verifyRs256(jwt: string, publicKey: crypto.KeyLike): boolean {
  const i = jwt.lastIndexOf(".");
  return crypto.verify("sha256", Buffer.from(jwt.slice(0, i)), publicKey, Buffer.from(jwt.slice(i + 1), "base64url"));
}
