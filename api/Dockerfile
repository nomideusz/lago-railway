# Lago's API, Sidekiq worker and clock in one container (see
# railway-entrypoint.sh for why).
FROM getlago/api:v1.54.0
USER root
# One Railway volume at /data: Active Storage files (invoice PDFs, exports)
# under /data/storage, the generated RSA key beside it, outside what Rails serves.
RUN rm -rf /app/storage && ln -s /data/storage /app/storage
COPY --chmod=755 railway-entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
CMD []
