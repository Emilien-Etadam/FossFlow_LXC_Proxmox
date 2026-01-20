# FossFLOW LXC Script for Proxmox VE

Script d'installation automatisé de [FossFLOW](https://github.com/stan-smith/FossFLOW) dans un conteneur LXC Proxmox, compatible avec le standard [VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE).

## 🚀 Installation

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

## 📋 Configuration par défaut

| Paramètre | Valeur |
|-----------|--------|
| OS | Debian 12 |
| Type | Unprivileged |
| CPU | 2 cores |
| RAM | 1024 MB |
| Disk | 4 GB |
| Port | 3000 |

## 🔄 Mise à jour

Pour mettre à jour FossFLOW, exécuter le même script depuis le shell Proxmox. Il détectera l'installation existante et proposera la mise à jour.

## 📁 Structure

```
├── ct/
│   ├── fossflow.sh          # Script principal (création LXC + update)
│   └── fossflow-install     # Script d'installation dans le LXC
└── frontend/
    └── public/json/
        └── fossflow.json    # Métadonnées
```

## 🔧 Ce qui est installé

- **Node.js 20.x** (via NodeSource)
- **FossFLOW v1.9.2** (dernière release depuis GitHub)
- **serve** (pour servir le frontend statique)
- **Deux services systemd** :
  - `fossflow-frontend` : Interface web sur port **3000**
  - `fossflow-backend` : API REST sur port **3001**
- **Stockage persistant** : `/opt/fossflow-data/diagrams`

## 📝 Notes

- Installation **native** (pas de Docker dans le LXC)
- Architecture **monorepo** avec frontend (React) et backend (Node.js/Express) séparés
- Le frontend communique avec le backend via l'API `/api/storage/*`
- Stockage serveur activé par défaut pour la persistance des diagrammes
- Auto-save toutes les 5 secondes dans le navigateur

## 🔍 Gestion des services

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

## 🔗 Liens

- [FossFLOW GitHub](https://github.com/stan-smith/FossFLOW)
- [FossFLOW Demo](https://stan-smith.github.io/FossFLOW/)
- [Community Scripts](https://github.com/community-scripts/ProxmoxVE)
