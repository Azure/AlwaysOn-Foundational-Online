# Even though we're not building but only installing, we're still doing multi-stage because grafana does not have NPM
FROM node:22 as builder

# Copy all source files over to our working directory
WORKDIR /app
COPY . .

# The queries are stored separately from the dashboard definitions, for maintainability reasons. 
# The insertqueries script replaces the placeholders in the dashboard files with the actual KQL queries 
WORKDIR /app/config
RUN chmod +x insertqueries.sh && ./insertqueries.sh

# The healthmodel panel is a third party component, published on NPM. 
# It contains only the built solution, so there is nothing to build, only install. 
# We set the workdir before installing to give us an easy way to copy everything out to the Grafana container. 
WORKDIR /app/healthmodelpanel
RUN npm install

FROM grafana/grafana:11.3.1

# In order to run unsigned plugins such as our health model panel, we need to explicitly allow them in an env variable. 
ENV GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS="healthmodelpanel"

# Copy the files from the build container to the Grafana container.
WORKDIR /var/lib/grafana/plugins/alwayson-healthmodelpanel/
COPY --from=builder /app/healthmodelpanel/* ./
COPY --from=builder /app/config/grafana.ini /etc/grafana/
COPY --from=builder /app/config/provisioning /etc/grafana/provisioning/

# Web server runs on 3000, we'll tell AppService to redirect traffic there. 
EXPOSE 3000/tcp