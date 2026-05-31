import { ContainerAppsAPIClient } from '@azure/arm-appcontainers';
import { ManagedIdentityCredential } from '@azure/identity';
import http from 'http';

const SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID ?? '';
const RG = process.env.RESOURCE_GROUP ?? 'infra-rg';
const ACR = process.env.ACR_SERVER ?? 'transporteescolarcs.azurecr.io';
const CLIENT_ID = process.env.AZURE_CLIENT_ID;
const PORT = parseInt(process.env.PORT ?? '8080', 10);

const REPO_TO_APP: Record<string, string> = {
  'api-gateway':          'api-gateway',
  'auth-service':         'auth-service',
  'presenca-service':     'presenca-service',
  'register-adm-service': 'register-adm-service',
  'relatorio-service':    'relatorio-service',
};

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
  const chunks: Buffer[] = [];
  req.on('data', (c: Buffer) => chunks.push(c));
  req.on('end', () => {
    try {
      const body = JSON.parse(Buffer.concat(chunks).toString());
      const target = (body?.target ?? {}) as Record<string, string>;
      const repo = target.repository ?? '';
      const tag = target.tag || 'latest';
      res.writeHead(202).end();
      deploy(repo, tag).catch(console.error);
    } catch {
      res.writeHead(400).end();
    }
  });
});

server.listen(PORT, () => console.log(`webhook receiver listening on :${PORT}`));
