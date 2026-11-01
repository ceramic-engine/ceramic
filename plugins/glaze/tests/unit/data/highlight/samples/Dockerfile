# syntax=docker/dockerfile:1
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci && npm run build
ENV NODE_ENV=production PORT=8080
EXPOSE 8080
CMD ["node", "dist/server.js"]
