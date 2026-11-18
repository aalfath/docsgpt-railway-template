# DocsGPT for Railway.
# Official image, pinned by version and multi-arch digest. To update: bump both,
# add a CHANGELOG.md entry, and merge to main (deployers get an update notice).
FROM arc53/docsgpt:1.1.0@sha256:761de60b3d1a683c9a2537d3b194b6858b6726934fd7f80f95b99aa87f466fbb

# Railway volumes are mounted owned by root, so the wrapper runs as root, as
# upstream's own Compose files do (`user: root`).
USER root

# Runtime data (uploaded files, FAISS indexes, vector files) lives on the /data
# volume: DOCSGPT_HOME points there and the processes run from it. The code and
# the baked embedding models stay in /app (EMBEDDINGS_CACHE_DIR=/app/models).
ENV DOCSGPT_HOME=/data \
    PYTHONPATH=/app

COPY start.sh /usr/local/bin/docsgpt-railway-start
RUN chmod 755 /usr/local/bin/docsgpt-railway-start

EXPOSE 7091
CMD ["/usr/local/bin/docsgpt-railway-start"]
