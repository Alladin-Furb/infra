# Build: compile TypeScript
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm install
COPY src/ ./src/
RUN npm run build

# Runtime: Node.js only — sem Azure CLI na imagem
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY --from=builder /app/dist/webhook.js .
EXPOSE 8080
CMD ["node", "webhook.js"]
