# Set host user and group id for all stages
ARG HOST_USER_UID=1001
ARG HOST_USER_GID=1001

# Vue.js SPA to Consume the API
FROM node:lts-alpine as spa

ARG HOST_USER_UID
ARG HOST_USER_GID

WORKDIR /app
COPY . .

# Add the user that will be expected
RUN addgroup --gid ${HOST_USER_GID} app
RUN adduser --system --no-create-home --uid $HOST_USER_UID --ingroup app webuser

RUN chown -R webuser:app /app

