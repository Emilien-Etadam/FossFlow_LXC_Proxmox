# FossFLOW LXC Script for Proxmox VE

[🇫🇷 Version Française](#version-française) | [🇬🇧 English Version](#english-version)

---

## 🇬🇧 English Version

Automated installation script for [FossFLOW](https://github.com/stan-smith/FossFLOW) in a Proxmox LXC container, compliant with [VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE) standards.

### 🚀 Installation

Run in Proxmox shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Emilien-Etadam/FossFlow_LXC_Proxmox/main/ct/fossflow.sh)"
```

The script will guide you through:
1. **Template storage selection** (auto-select if only one available)
2. **Container storage selection** (with free space display)
3. **Debian 12 template download** (if needed)
4. **LXC container creation and configuration**
5. **Node.js 20.x and FossFLOW installation**

### 📋 Default Configuration

| Parameter | Value |
|-----------|-------|
| OS | Debian 12 |
| Type | Unprivileged |
| CPU | 2 cores |
| RAM | 1024 MB |
| Disk | 4 GB |
| Port | 3000 |

### 🔄 Updates

To update FossFLOW, run the same script from the Proxmox shell. It will detect the existing installation and offer to update it.

### 📁 Repository Structure

```
├── ct/
│   ├── fossflow.sh          # Main script (LXC creation + update)
│   └── fossflow-install     # Installation script inside LXC
└── frontend/
    └── public/json/
        └── fossflow.json    # Metadata
```

### 🔧 What Gets Installed

- **Node.js 20.x** (via NodeSource)
- **FossFLOW v1.9.2** (latest release from GitHub)
- **serve** (to serve frontend static files)
- **Two systemd services**:
  - `fossflow-frontend`: Web interface on port **3000**
  - `fossflow-backend`: REST API on port **3001**
- **Persistent storage**: `/opt/fossflow-data/diagrams`

### 📝 Notes

- **Native** installation (no Docker in LXC)
- **Monorepo** architecture with separate frontend (React) and backend (Node.js/Express)
- Frontend communicates with backend via `/api/storage/*` API
- Server storage enabled by default for diagram persistence
- Auto-save every 5 seconds in browser

### 🔍 Service Management

```bash
# Check status
systemctl status fossflow-frontend
systemctl status fossflow-backend

# Restart services
systemctl restart fossflow-frontend
systemctl restart fossflow-backend

# View logs
journalctl -u fossflow-frontend -f
journalctl -u fossflow-backend -f
```

### 🔗 Links

- [FossFLOW GitHub](https://github.com/stan-smith/FossFLOW)
- [FossFLOW Demo](https://stan-smith.github.io/FossFLOW/)
- [Community Scripts](https://github.com/community-scripts/ProxmoxVE)

---

## 🇫🇷 Version Française

Script d'installation automatisé de [FossFLOW](https://github.com/stan-smith/FossFLOW) dans un conteneur LXC Proxmox, compatible avec le standard [VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE).

### 🚀 Installation

Exécuter dans le shell Proxmox :

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Emilien-Etadam/FossFlow_LXC_Proxmox/main/ct/fossflow.sh)"
```

Le script vous guidera à travers :
1. **Sélection du storage pour templates** (auto-sélection si un seul disponible)
2. **Sélection du storage pour le conteneur** (avec affichage de l'espace libre)
3. **Téléchargement du template Debian 12** (si nécessaire)
4. **Création et configuration du conteneur LXC**
5. **Installation de Node.js 20.x et FossFLOW**

### 📋 Configuration par défaut

| Paramètre | Valeur |
|-----------|--------|
| OS | Debian 12 |
| Type | Unprivileged |
| CPU | 2 cores |
| RAM | 1024 MB |
| Disk | 4 GB |
| Port | 3000 |

### 🔄 Mise à jour

Pour mettre à jour FossFLOW, exécuter le même script depuis le shell Proxmox. Il détectera l'installation existante et proposera la mise à jour.

### 📁 Structure

```
├── ct/
│   ├── fossflow.sh          # Script principal (création LXC + update)
│   └── fossflow-install     # Script d'installation dans le LXC
└── frontend/
    └── public/json/
        └── fossflow.json    # Métadonnées
```

### 🔧 Ce qui est installé

- **Node.js 20.x** (via NodeSource)
- **FossFLOW v1.9.2** (dernière release depuis GitHub)
- **serve** (pour servir le frontend statique)
- **Deux services systemd** :
  - `fossflow-frontend` : Interface web sur port **3000**
  - `fossflow-backend` : API REST sur port **3001**
- **Stockage persistant** : `/opt/fossflow-data/diagrams`

### 📝 Notes

- Installation **native** (pas de Docker dans le LXC)
- Architecture **monorepo** avec frontend (React) et backend (Node.js/Express) séparés
- Le frontend communique avec le backend via l'API `/api/storage/*`
- Stockage serveur activé par défaut pour la persistance des diagrammes
- Auto-save toutes les 5 secondes dans le navigateur

### 🔍 Gestion des services

```bash
# Vérifier le statut
systemctl status fossflow-frontend
systemctl status fossflow-backend

# Redémarrer les services
systemctl restart fossflow-frontend
systemctl restart fossflow-backend

# Voir les logs
journalctl -u fossflow-frontend -f
journalctl -u fossflow-backend -f
```

### 🔗 Liens

- [FossFLOW GitHub](https://github.com/stan-smith/FossFLOW)
- [FossFLOW Demo](https://stan-smith.github.io/FossFLOW/)
- [Community Scripts](https://github.com/community-scripts/ProxmoxVE)
