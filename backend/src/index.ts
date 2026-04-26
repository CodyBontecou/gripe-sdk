import { Hono } from 'hono';
import { createIssue } from './github';
import { putImage, imageUrl } from './storage';
import { renderIssueBody, deriveTitle } from './issueBody';
import type { Bindings, GripeMetadata } from './types';

const app = new Hono<{ Bindings: Bindings }>();

app.get('/health', (c) => c.json({ ok: true }));

app.post('/v1/reports', async (c) => {
  const auth = c.req.header('authorization');
  const expected = `Bearer ${c.env.GRIPE_API_KEY}`;
  if (!auth || auth !== expected) {
    return c.json({ error: 'unauthorized' }, 401);
  }

  let form: FormData;
  try {
    form = await c.req.formData();
  } catch {
    return c.json({ error: 'invalid_multipart' }, 400);
  }

  const comment = (form.get('comment') ?? '').toString();
  const metadataRaw = (form.get('metadata') ?? '').toString();
  const repositoryOverride = (form.get('repository') ?? '').toString();
  const repository = repositoryOverride || c.env.GITHUB_REPO;
  if (!repository) {
    return c.json({ error: 'repository_required' }, 400);
  }
  const imageEntry = form.get('image');
  if (!imageEntry || typeof imageEntry === 'string') {
    return c.json({ error: 'image_required' }, 400);
  }
  const image = imageEntry as Blob;

  let metadata: GripeMetadata;
  try {
    metadata = JSON.parse(metadataRaw);
  } catch {
    return c.json({ error: 'invalid_metadata_json' }, 400);
  }

  const reportId = crypto.randomUUID();
  const key = `reports/${reportId}.png`;
  const bytes = new Uint8Array(await image.arrayBuffer());

  try {
    await putImage(c.env, key, bytes);
  } catch (err) {
    return c.json({ error: 'storage_failed', detail: String(err) }, 502);
  }

  const url = imageUrl(c.env, key);
  const body = renderIssueBody({ comment, metadata, imageUrl: url });
  const title = deriveTitle(comment, metadata);

  try {
    const issue = await createIssue(c.env, { title, body, labels: ['gripe'], repository });
    return c.json({ issueUrl: issue.html_url, issueNumber: issue.number }, 201);
  } catch (err) {
    return c.json({ error: 'github_failed', detail: String(err) }, 502);
  }
});

app.get('/images/:key{.+}', async (c) => {
  const key = c.req.param('key');
  const obj = await c.env.GRIPE_IMAGES.get(key);
  if (!obj) return c.notFound();
  return new Response(obj.body, {
    headers: {
      'content-type': obj.httpMetadata?.contentType ?? 'image/png',
      'cache-control': 'public, max-age=31536000, immutable',
    },
  });
});

export default app;
