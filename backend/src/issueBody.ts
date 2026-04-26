import type { GripeMetadata } from './types';

export function renderIssueBody(args: {
  comment: string;
  metadata: GripeMetadata;
  imageUrl: string;
}): string {
  const { comment, metadata, imageUrl } = args;
  const trimmedComment = comment.trim();
  const lines: string[] = [];

  if (trimmedComment) {
    lines.push(trimmedComment, '');
  }

  lines.push(`![screenshot](${imageUrl})`, '', '---', '', '<sub>');
  lines.push(`**Device**: ${metadata.deviceModel} — ${metadata.osName} ${metadata.osVersion}<br>`);
  lines.push(`**App**: ${metadata.appVersion} (${metadata.build}) — \`${metadata.bundleIdentifier}\`<br>`);
  if (metadata.viewControllerName) {
    lines.push(`**View**: \`${metadata.viewControllerName}\`<br>`);
  }
  lines.push(`**Locale**: ${metadata.locale}<br>`);
  lines.push(`**Captured**: ${metadata.capturedAt}`);
  lines.push('</sub>');

  return lines.join('\n');
}

export function deriveTitle(comment: string, metadata: GripeMetadata): string {
  const trimmed = comment.trim();
  if (trimmed.length > 0) {
    return truncate(trimmed.split('\n')[0], 70);
  }
  const view = metadata.viewControllerName ? ` on ${metadata.viewControllerName}` : '';
  return `Gripe${view} (${metadata.deviceModel})`;
}

function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 1).trimEnd() + '…';
}
