FROM envoyproxy/envoy:v1.32.5

COPY envoy.yaml /etc/envoy/envoy.yaml

EXPOSE 80

CMD ["envoy", "-c", "/etc/envoy/envoy.yaml"]
