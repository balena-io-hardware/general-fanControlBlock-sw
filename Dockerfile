FROM balenalib/aarch64-alpine:run

COPY fan-control.sh restart-policy.sh /
RUN chmod +x /fan-control.sh /restart-policy.sh

CMD /restart-policy.sh /fan-control.sh
