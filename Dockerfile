FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
COPY . .
ARG TMDB_V3_API_KEY
ARG API_ENDPOINT_URL=https://api.themoviedb.org/3
RUN echo "VITE_APP_TMDB_V3_API_KEY=${TMDB_V3_API_KEY}" > .env && \
    echo "VITE_APP_API_ENDPOINT_URL=${API_ENDPOINT_URL}" >> .env && \
    cat .env
RUN yarn build

FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]