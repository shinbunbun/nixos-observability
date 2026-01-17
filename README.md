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

### 1. Add to your `flake.nix`

```nix
{
  inputs.nixos-observability = {
    url = "github:shinbunbun/nixos-observability";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### 2. Import modules

```nix
{
  imports = [ inputs.nixos-observability.nixosModules.default ];
}
```

### 3. Basic configuration

```nix
{
  services.observability = {
    # Monitoring stack
    monitoring = {
      enable = true;
      prometheus.port = 9090;
      grafana = {
        domain = "grafana.example.com";
        dashboards.path = inputs.nixos-observability.assets.dashboards;
      };
    };

    # Alertmanager with your alert rules
    alertmanager = {
      enable = true;
      discord.webhookUrlFile = "/path/to/discord/webhook";
      alertRules = import ./my-alert-rules.nix;  # Your custom alert rules
    };

    # Loki for log aggregation
    loki = {
      enable = true;
      retentionDays = 30;
      rulesFile = inputs.nixos-observability.assets.lokiRules;
    };

    # Fluent Bit for log collection
    fluentBit = {
      enable = true;
      configFile = ./fluent-bit.conf;  # Your custom config
    };
  };
}
```

## Documentation

- [Getting Started](docs/getting-started.md)
- [Configuration Reference](docs/configuration.md)

## Examples

See [examples/](examples/) directory for complete configuration examples.

## Modules

All modules are fully functional and ready for production use:

- ✅ **monitoring** - Prometheus, Grafana, Node Exporter, SNMP Exporter
- ✅ **alertmanager** - Alert management with Discord notifications
- ✅ **loki** - Log aggregation and search
- ✅ **opensearch** - Advanced log search and analysis
- ✅ **opensearchDashboards** - Log visualization UI (Docker)
- ✅ **fluentBit** - Lightweight log collection agent

## Architecture

This project follows a **policy-free** design:

- **Modules provide tools** - nixos-observability provides NixOS modules for observability tools
- **You define policy** - Alert rules, dashboards, and log processing configs are injected from your dotfiles
- **Maximum flexibility** - Use only what you need, configure as you want

### Example: Alert Rules

Alert rules are **not** included in nixos-observability. You define them in your dotfiles:

```nix
# your-dotfiles/observability-config/alert-rules.nix
[
  {
    name = "system";
    interval = "30s";
    rules = [
      {
        alert = "InstanceDown";
        expr = "up == 0";
        for = "2m";
        labels.severity = "critical";
      }
    ];
  }
]
```

Then inject them via options:

```nix
services.observability.alertmanager.alertRules = import ./observability-config/alert-rules.nix;
```

## Assets

Pre-configured assets are provided for convenience:

- `assets/dashboards/` - Grafana dashboards (system, RouterOS, logs)
- `assets/lokiRules` - Sample Loki alert rules
- `assets/snmpConfig` - SNMP Exporter config for MikroTik RouterOS

## License

MIT License - see [LICENSE](LICENSE) file for details.
