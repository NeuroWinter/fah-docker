FROM fedora:latest
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh
CMD ["/bin/bash", "-c", "sleep 600 && exec /usr/local/bin/run.sh"]
