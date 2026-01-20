# FossFLOW LXC Script for Proxmox VE

Script d'installation automatisé de [FossFLOW](https://github.com/stan-smith/FossFLOW) dans un conteneur LXC Proxmox, style [community-scripts](https://github.com/community-scripts/ProxmoxVE).

## 🚀 Installation

Exécuter dans le shell Proxmox :

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Emilien-Etadam/FossFlow_LXC_Proxmox/main/ct/fossflow.sh)"
```

## 📋 Configuration par défaut

| Paramètre | Valeur |
|-----------|--------|
| OS | Debian 12 |
| CPU | 2 cores |
| RAM | 1024 MB |
| Disk | 4 GB |
| Port | 3000 |

## 🔄 Mise à jour

Pour mettre à jour FossFLOW, exécuter le même script depuis le shell Proxmox. Il détectera l'installation existante et proposera la mise à jour.

## 📁 Structure

```
├── ct/
│   └── fossflow.sh          # Script principal (création LXC + update)
├── install/
│   └── fossflow-install.sh  # Script d'installation dans le LXC
└── frontend/
    └── public/json/
        └── fossflow.json    # Métadonnées
```

## 🔧 Ce qui est installé

- Node.js 20.x
- FossFLOW (dernière release)
- Service systemd `fossflow`
- Stockage serveur activé dans `/opt/fossflow-data/diagrams`

## 📝 Notes

- Installation **native** (pas de Docker dans le LXC)
- Stockage persistant des diagrammes côté serveur
- Auto-save toutes les 5 secondes dans le navigateur

## 🔗 Liens

- [FossFLOW GitHub](https://github.com/stan-smith/FossFLOW)
- [FossFLOW Demo](https://stan-smith.github.io/FossFLOW/)
- [Community Scripts](https://github.com/community-scripts/ProxmoxVE)
