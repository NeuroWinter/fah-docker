FROM fedora:latest
COPY ./install-tor-fedora.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh
RUN head -c 2G /dev/zero | tr '\000' '\064' > /opt/fill_34_2G.bin
CMD ["/bin/bash", "-c", "sleep 600 && exec /usr/local/bin/run.sh"]
