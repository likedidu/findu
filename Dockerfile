FROM node:20.6.1-bookworm

WORKDIR /app

COPY . .

ENV PORT=3000
ENV SecretPATH=/mypath

RUN set -ex \
    && yarn install \
    && yarn global add pm2

ENTRYPOINT ["yarn", "start"]
