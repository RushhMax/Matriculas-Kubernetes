FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.25-alpine
COPY --from=build /app/dist                           /usr/share/nginx/html
COPY nginx.conf.template                              /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.sh                             /docker-entrypoint.sh
# Evita que un checkout en Windows deje CRLF en el shebang del script Linux.
RUN sed -i 's/\r$//' /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh
ENV BACKEND_URL=http://backend:3000
EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
