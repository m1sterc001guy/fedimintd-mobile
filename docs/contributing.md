# Contributing

## Development

Fedimint Mobile uses nix and nix flakes to manage dependencies and build the project.

### Installing Nix

First, install nix:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Enter Developer Environment

Then enter the nix developer environment. First invocation will take some time.

```bash
nix develop
```

### Building

To build APK, run:

```bash
just build-debug-apk
```
