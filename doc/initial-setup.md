# Intial Setup

# Premier démarrage

Mise à jour de debian

```bash
apt-get update && apt-get upgrade -y
```

Réglage de la timezone

```bash
timedatectl set-timezone Europe/Paris
```

Vérification de la la timezone

```bash
timedatectl 
```

Installation de différents package

```bash
apt-get install -y curl sudo mc
apt-get install -y sudo
apt-get install -y mc

```