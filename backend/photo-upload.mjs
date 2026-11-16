import { Buffer } from 'node:buffer';

export const MAX_PHOTO_BASE64_BYTES = 400_000;

/** @param {unknown} value */
export function isBoundedJPEG(value) {
  if (typeof value !== 'string' || value.length > MAX_PHOTO_BASE64_BYTES ||
      value.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return false;
  const bytes = Buffer.from(value, 'base64');
  return bytes.length >= 5 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 &&
    bytes[bytes.length - 2] === 255 && bytes[bytes.length - 1] === 217;
}
