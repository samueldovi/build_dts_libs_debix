# Installation de l'environnement Yocto - i.MX8MP EVK

## 1. Préparation du système hôte (PC)

Votre PC doit fonctionner sous Ubuntu (20.04 ou 22.04 LTS recommandé ou WSL). Installez les paquets requis :

```bash
sudo apt update
sudo apt install gawk wget git diffstat unzip texinfo gcc build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev pylint xterm python3-subunit mesa-common-dev zstd liblz4-tool libssl-dev
```
## 2. Installation de l'environnement de dévelopement.

Ce script va installer l'environnement yocto et copier les scripts utilitaires dans le dossier build.

```bash
source install.sh
```

## 3. Configuration des scripts de déploiement

### Fichier `debix.conf`:

```
TARGET_IP=192.168.1.xxx  # Adresse IP de votre carte EVK
TARGET_USER=root         # Utilisateur par défaut
```

---

## 4. Utilisation rapide

### Compiler et envoyer une librairie :

Inutile de faire un `bitbake` complet de l'image. Utilisez le script pour cibler uniquement ce dont vous avez besoin :

> Note : Si vous cherchez le nom exacts des bibliothèques voir : https://layers.openembedded.org/

```bash
./deploy_libs.sh lib1 lib2 lib3 ...
```

*example:*
```bash
./deploy_libs.sh opencv python
```

### Compiler et envoyer un Device Tree :

Le script compile votre `.dts` local et l'envoie dans `/boot/` sur la carte :

```bash
./deploy_dts.sh <fichier.dts>
```yocto

*example:*
```bash
./deploy_dts.sh imx8mp-evk.dts
```

---
### Nota bene:

- Assurez-vous que la carte EVK est pingable depuis votre PC avant de lancer les scripts de déploiement.
* Si les scripts ne se lancent pas, faites `chmod +x *.sh`.
*  Pour retirer une librairie installée par le script : `devtool undeploy-target <nom_lib> root@<IP_CARTE>`.
*  Pour voir si une librairie est bien sur la carte : `ls /usr/lib | grep <nom>`.