# 🚀 Universal Deploy

**Système de déploiement universel de scripts Linux**

Déployez vos scripts système, monitoring, sécurité et configurations sur n'importe quel serveur Linux en une seule commande.



## ⚡ Installation

Sur votre nouveau serveur, copiez-collez cette commande :

```bash
apt-get update && apt-get install -y git && git clone https://github.com/Phips02/universal-deploy.git && cd universal-deploy && chmod +x deploy.sh && ./deploy.sh
```


## 📖 Utilisation

**Mode interactif** (par défaut) :
```bash
./deploy.sh
```
Navigation : `a` (tout sélectionner), `n` (rien), `Enter` (installer), `q` (quitter)

**Commandes utiles** :
```bash
./deploy.sh --list-available    # Lister les scripts
./deploy.sh --list-installed    # Voir ce qui est installé
./deploy.sh --update-all        # Mettre à jour tout
./deploy.sh --help              # Aide complète
```

---

## 📁 Structure

```
universal-deploy/
├── deploy.sh              # Script principal
├── scripts/               # Scripts organisés par catégorie
│   ├── base/
│   ├── security/
│   ├── monitoring/
│   ├── network/
│   └── backup/
├── config/                # Profils et templates
└── lib/                   # Fonctions internes
```

---

## 🎨 Scripts Disponibles

### 📦 Base (Système)
- ✅ **00_lxc-details.sh** - Affichage des informations système au login (LXC/VM)
- ✅ **prompt-setup.sh** - Configuration du prompt bash personnalisé et coloré

### 🔒 Security (En cours de migration)
- 🔄 **fail2ban** - Protection contre les attaques brute-force
- 🔄 **2fa-totp** - Authentification à deux facteurs TOTP obligatoire pour root
- 🔄 **ssh-hardening** - Durcissement de la configuration SSH
- 🔄 **ssh-bastion** - Configuration connexion SSH via bastion
- 🔄 **firewall-iptables** - Configuration du firewall iptables
- 🔄 **auto-security-updates** - Mises à jour de sécurité automatiques

### 🌐 Network (En cours de migration)
- 🔄 **tailscale-client** - Configuration client Tailscale vers serveur Headscale

### 📊 Monitoring (En cours de migration)
- 🔄 **zabbix-agent** - Installation et configuration de Zabbix Agent
- 🔄 **telegram-notifications** - Notifications Telegram en temps réel

### 💾 Backup (En cours de migration)
- 🔄 **daily-config-backup** - Sauvegarde quotidienne de la configuration système

---

## 📝 Ajouter un Script

1. Créez votre script : `scripts/security/mon_script.sh`
2. Créez les métadonnées : `scripts/security/mon_script.sh.meta.json`
```json
{
  "name": "mon_script",
  "display_name": "Mon Super Script",
  "description": "Description",
  "category": "security",
  "version": "1.0",
  "destination": "/usr/local/bin/"
}
```
3. Testez : `./deploy.sh --dry-run`

Le script apparaît automatiquement dans l'interface !

---

## 🔧 Profils

- **base** : Scripts système essentiels
- **security** : Hardening et sécurité
- **monitoring** : Monitoring complet
- **vpn-server** : Configuration serveur VPN

Utilisation : `./deploy.sh --auto --profile base`

---

## 📊 Tracking

Les installations sont trackées dans `/etc/deployed-scripts/.installed` (versions, dates, checksums).

Voir l'historique : `./deploy.sh --list-installed`

---

## 📄 Licence

MIT License

## 📞 Support

Questions ou problèmes : [Ouvrir une issue](https://github.com/Phips02/universal-deploy/issues)

---

## 🎯 Roadmap

### Phase 1 : Migration des Scripts Existants (En cours)
- [x] ✅ Système de base opérationnel avec interface checklist
- [x] ✅ Scripts de base (infos système, prompt)
- [ ] Connexion a un serveur NTP Suisse avec time zone Zurich
- [ ] 🔄 Migration des scripts de sécurité (Priorité Haute)
  - [ ] fail2ban
  - [ ] 2FA TOTP pour root
  - [ ] SSH hardening
  - [ ] SSH via bastion
  - [ ] Firewall iptables
  - [ ] Chiffrement LUKS /home avec déchiffrement
  - [ ] Mises à jour auto de sécurité
- [ ] 🔄 Migration des scripts réseau
  - [ ] Tailscale Client
- [ ] 🔄 Migration des scripts de monitoring
  - [ ] Zabbix Agent 
  - [ ] Notifications Telegram temps réel
- [ ] 🔄 Migration des scripts de backup
  - [ ] Backup quotidien de configuration système


### Phase 2 : Améliorations
- [ ] Templates de configuration pour chaque script
- [ ] Profils prédéfinis complets
  - [ ] Profil "bastion" (SSH durci, 2FA, chiffrement, backups)
  - [ ] Profil "vpn-server" (OpenVPN + Duo, fail2ban, firewall)
  - [ ] Profil "monitoring" (Zabbix, Telegram, system info)
  - [ ] Profil "backup-server" (rsync, backups quotidiens, notifications)
- [ ] Tests automatisés des scripts
- [ ] Documentation détaillée par script
- [ ] Guide de migration depuis serveurs existants

### Phase 3 : Fonctionnalités Avancées
- [ ] Détection automatique des mises à jour de scripts
- [ ] Export/Import de configurations complètes

---

