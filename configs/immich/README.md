# Immich on ENDOR

Rootless Podman 5 pod + Quadlets. Observed 2026-09-07.

Server and ML get CDI `nvidia.com/gpu=0`. ML image is the CUDA tag with `--disable-cuda-graph`. Machine learning is healthy after a HealthCmd quoting fix on Podman 5.7.0. That is process liveness, not an embeddings benchmark.

Published paths use `/srv/immich/*` and `/srv/photos`. LAN bind uses documentation address 192.0.2.10. Passwords in the units are placeholders (`changeme`).
