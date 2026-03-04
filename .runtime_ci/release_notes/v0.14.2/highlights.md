* Aligned ecosystem dependencies (`sentry`, `grpc`, `encrypt`, `image`, and `runtime_isomorphic_library`) post-merge for consumer applications.
* Reconfigured CI workflows to use `ubuntu-latest` and `windows-latest` GitHub-hosted runners for x64 architecture builds.
* Updated `.runtime_ci/config.json` to define permanent runner overrides for x64 platforms to avoid large self-hosted runner queue times.
