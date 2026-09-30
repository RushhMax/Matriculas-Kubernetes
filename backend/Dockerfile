FROM node:20-alpine
ARG APP_VERSION=demo-v1.1.0
ENV APP_VERSION=$APP_VERSION
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src
EXPOSE 3000
CMD ["node", "src/index.js"]
