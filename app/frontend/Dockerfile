FROM nginx:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html
COPY default.conf.template /etc/nginx/templates/default.conf.template

# Can be overridden via env for local testing
ENV BACKEND_HOST=backend
ENV BACKEND_PORT=3000

EXPOSE 80
