import type { Bindings } from './types';

interface CreateIssueInput {
  title: string;
  body: string;
  labels?: string[];
}

interface GitHubIssue {
  html_url: string;
  number: number;
}

export async function createIssue(env: Bindings, input: CreateIssueInput): Promise<GitHubIssue> {
  const [owner, repo] = env.GITHUB_REPO.split('/');
  if (!owner || !repo) {
    throw new Error(`invalid GITHUB_REPO: ${env.GITHUB_REPO}`);
  }

  const res = await fetch(`https://api.github.com/repos/${owner}/${repo}/issues`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'gripe-sdk',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      title: input.title,
      body: input.body,
      labels: input.labels,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GitHub ${res.status}: ${text}`);
  }
  return (await res.json()) as GitHubIssue;
}
