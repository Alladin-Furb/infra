import { ContainerAppsAPIClient } from '@azure/arm-appcontainers';
import { ManagedIdentityCredential } from '@azure/identity';
import http from 'http';

const SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID ?? '';
const RG = process.env.RESOURCE_GROUP ?? 'infra-rg';
const ACR = process.env.ACR_SERVER ?? 'transporteescolarcs.azurecr.io';
const CLIENT_ID = process.env.AZURE_CLIENT_ID;
const PORT = parseInt(process.env.PORT ?? '8080', 10);
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET ?? '';

const DEFAULT_REPO_TO_APP: Record<string, string> = {
  'api-gateway':          'api-gateway',
  'auth-service':         'auth-service',
  'presenca-service':     'presenca-service',
  'register-adm-service': 'register-adm-service',
  'relatorio-service':    'relatorio-service',
  'route-generator':      'route-generator',
};

function loadRepoToApp(): Record<string, string> {
  const raw = process.env.REPO_TO_APP_MAP;
  if (!raw) return DEFAULT_REPO_TO_APP;
  try {
    return JSON.parse(raw) as Record<string, string>;
  } catch {
    console.warn('[config] REPO_TO_APP_MAP is not valid JSON, using defaults');
    return DEFAULT_REPO_TO_APP;
  }
}

const REPO_TO_APP = loadRepoToApp();

const credential = new ManagedIdentityCredential(CLIENT_ID ? { clientId: CLIENT_ID } : {});
const appsClient = new ContainerAppsAPIClient(credential, SUBSCRIPTION_ID);

async function deploy(repository: string, tag: string): Promise<void> {
  const app = REPO_TO_APP[repository];
  if (!app) {
    console.log(`[skip] no mapping for: ${repository}`);
    return;
  }
  const image = `${ACR}/${repository}:${tag}`;
  console.log(`[deploy] ${image} → ${app}`);
  try {
    const current = await appsClient.containerApps.get(RG, app);
    if (current.template?.containers?.[0]) {
      current.template.containers[0].image = image;
    }
    // Azure returns secrets without values on GET; re-sending them causes
    // ContainerAppSecretInvalid. Remove from the PATCH payload so Azure
    // keeps the existing secret values unchanged.
    if (current.configuration) {
      current.configuration.secrets = undefined;
    }
    // Use the commit tag as the revision suffix to guarantee uniqueness.
    if (current.template) {
      current.template.revisionSuffix = tag.replace(/[^a-z0-9]/gi, '').toLowerCase().slice(0, 24);
    }
    await appsClient.containerApps.beginUpdateAndWait(RG, app, current);
    console.log(`[ok] ${app} updated`);
  } catch (err) {
    console.error(`[error] ${app}:`, err);
  }
}

const server = http.createServer((req, res) => {
  if (req.method !== 'POST') {
    res.writeHead(405).end();
    return;
  }

  if (WEBHOOK_SECRET) {
    const authHeader = req.headers['authorization'] ?? '';
    if (authHeader !== `Bearer ${WEBHOOK_SECRET}`) {
      res.writeHead(401).end();
      return;
    }
  }

  const chunks: Buffer[] = [];
  req.on('data', (c: Buffer) => chunks.push(c));
  req.on('end', () => {
    try {
      const body = JSON.parse(Buffer.concat(chunks).toString());
      const target = (body?.target ?? {}) as Record<string, string>;
      const repo = target.repository ?? '';
      const tag = target.tag ?? '';
      res.writeHead(202).end();
      // CI publishes two tags per build (`latest` + `sha-<short>`), so two push
      // events arrive for the same digest. Act only on the immutable `sha-*` tag:
      // it is unique per commit, guaranteeing a fresh revision. Skipping `latest`
      // avoids the no-op redeploy (same image reference) and the duplicate deploy.
      if (!tag.startsWith('sha-')) {
        console.log(`[skip] ${repo}: tag '${tag}' is not sha-*, ignoring`);
        return;
      }
      deploy(repo, tag).catch(console.error);
    } catch {
      res.writeHead(400).end();
    }
  });
});

server.listen(PORT, () => console.log(`webhook receiver listening on :${PORT}`));
