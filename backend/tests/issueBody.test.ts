import { describe, it, expect } from 'vitest';
import { renderIssueBody, deriveTitle } from '../src/issueBody';
import type { GripeMetadata } from '../src/types';

const meta: GripeMetadata = {
  appVersion: '1.2.3',
  build: '456',
  bundleIdentifier: 'com.example.app',
  osName: 'iOS',
  osVersion: '18.0',
  deviceModel: 'iPhone15,3',
  screenWidth: 390,
  screenHeight: 844,
  capturedAt: '2026-04-25T22:00:00Z',
  viewControllerName: 'HomeViewController',
  locale: 'en_US',
};

describe('renderIssueBody', () => {
  it('embeds comment, image, and metadata', () => {
    const body = renderIssueBody({
      comment: 'Login button is broken',
      metadata: meta,
      imageUrl: 'https://x/y.png',
    });
    expect(body).toContain('Login button is broken');
    expect(body).toContain('![screenshot](https://x/y.png)');
    expect(body).toContain('iPhone15,3');
    expect(body).toContain('HomeViewController');
    expect(body).toContain('1.2.3 (456)');
  });

  it('omits the comment block when whitespace-only', () => {
    const body = renderIssueBody({ comment: '   ', metadata: meta, imageUrl: 'u' });
    expect(body.startsWith('![screenshot]')).toBe(true);
  });

  it('omits the View row when no view controller name', () => {
    const m = { ...meta, viewControllerName: undefined };
    const body = renderIssueBody({ comment: '', metadata: m, imageUrl: 'u' });
    expect(body).not.toContain('**View**');
  });
});

describe('deriveTitle', () => {
  it('uses the first line of comment', () => {
    expect(deriveTitle('Hello world\nmore', meta)).toBe('Hello world');
  });

  it('truncates long comments', () => {
    const t = deriveTitle('a'.repeat(100), meta);
    expect(t.length).toBeLessThanOrEqual(70);
    expect(t.endsWith('…')).toBe(true);
  });

  it('falls back to view + device when comment is empty', () => {
    expect(deriveTitle('', meta)).toBe('Gripe on HomeViewController (iPhone15,3)');
  });
});
