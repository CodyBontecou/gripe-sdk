import type { Bindings } from './types';

export async function putImage(env: Bindings, key: string, bytes: Uint8Array): Promise<void> {
  await env.GRIPE_IMAGES.put(key, bytes, {
    httpMetadata: { contentType: 'image/png' },
  });
}

export function imageUrl(env: Bindings, key: string): string {
  const base = env.R2_PUBLIC_BASE.replace(/\/$/, '');
  return `${base}/${key}`;
}
