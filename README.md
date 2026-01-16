# NixOS Observability Stack

A comprehensive observability solution for NixOS, including:

- **Prometheus** - Metrics collection and storage
- **Grafana** - Metrics visualization
- **Alertmanager** - Alert management with Discord notifications
- **Loki** - Log aggregation
- **Fluent Bit** - Log collection
- **OpenSearch** - Log search and analysis
- **Node Exporter** - System metrics
- **SNMP Exporter** - Network device monitoring (MikroTik RouterOS)

## Features

- 🚀 Easy setup with NixOS Flakes
- 📊 Pre-configured Grafana dashboards
- 🔔 Discord alert notifications
- 🔒 SOPS-compatible secret management
- 📦 Modular architecture - enable only what you need
- 🎨 Customizable configurations

## Quick Start

Add to your `flake.nix`:

```nix
{
  inputs.nixos-observability = {
    url = "github:shinbunbun/nixos-observability";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Enable in your configuration:

```nix
{
  imports = [ inputs.nixos-observability.nixosModules.default ];

  services.observability = {
    monitoring.enable = true;
    alertmanager.enable = true;
    loki.enable = true;
  };
}
```

## Documentation

- [Getting Started](docs/getting-started.md)
- [Configuration Reference](docs/configuration.md)

## Examples

See [examples/](examples/) directory for complete configuration examples.

## Development Status

🚧 **This project is currently under active development.** Modules are being migrated and refactored for public use.

## License

MIT License - see [LICENSE](LICENSE) file for details.
