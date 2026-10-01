🌍 *[Click here for the English version](#english-version)* | 🇫🇷 *[Cliquez ici pour la version Française](#version-française)*

---

# 🇫🇷 Version Française

# 🎵 Téléchargeur de Musique (Spotify vers MP3)

## 📌 Contexte du projet
Ce script a été créé initialement pour répondre à mes besoins personnels. Il s'agit d'un script Bash conçu pour fonctionner sous **Linux**. Il permet de télécharger automatiquement des musiques depuis des liens Spotify (artistes ou playlists) au format MP3, en recherchant les morceaux sur YouTube et SoundCloud, puis en ajoutant les bonnes étiquettes (titre, artiste, album). Les musiques sont rangées proprement dans le dossier `~/Musique/`.

*🚀 **À venir :** Je prévois de l'adapter par la suite sous la forme d'un programme en Python pour qu'il soit compatible avec Windows et d'autres systèmes d'exploitation.*

## Sommaire
- [Étape 1 : Les dépendances à installer](#étape-1--les-dépendances-à-installer)
- [Étape 2 : La liste d'artistes / playlists (Comment ça marche)](#étape-2--la-liste-dartistes--playlists-comment-ça-marche)
- [Étape 3 : Le lancement du script](#étape-3--le-lancement-du-script)

## Étape 1 : Les dépendances à installer

Pour que le script fonctionne, vous avez besoin de quelques outils et du navigateur **Firefox** (qui sert à récupérer les cookies pour éviter d'être bloqué par YouTube).

**1. Installer les paquets systèmes (exemple pour Debian/Ubuntu/Mint) :**
```bash
sudo apt update
sudo apt install ffmpeg jq gawk python3-pip
```

**2. Installer les outils de téléchargement (via Python) :**
```bash
pip3 install yt-dlp spotdl
```

*(Note : Assurez-vous que Firefox est bien installé sur votre machine).*

## Étape 2 : La liste d'artistes / playlists (Comment ça marche)

Le script se base sur un fichier nommé `Artiste.json`. 

**Où est ce fichier ?** 
Il se trouve dans `~/Musique/Script_Musique/Artiste.json`. 
*(Astuce : Si le dossier ou le fichier n'existe pas, lancez le script une première fois, il les créera automatiquement).*

**Comment le remplir ?**
Ouvrez le fichier `Artiste.json` avec un éditeur de texte et ajoutez vos liens Spotify (liens d'artistes ou de playlists) sous forme de liste JSON. 

Voici le format exact à respecter :

```json
[
  "https://open.spotify.com/artist/4Z8W4fZZB5yRxXI2PEYkEX",
  "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
]
```
*(Attention à bien mettre les guillemets et la virgule, sauf pour la dernière ligne).*

## Étape 3 : Le lancement du script

**1. Rendre le script exécutable (à faire une seule fois) :**
Ouvrez un terminal là où se trouve votre script et tapez :
```bash
chmod +x Music.sh
```

**2. Lancer le script :**
```bash
./Music.sh
```

**3. Utiliser le menu :**
Une fois lancé, le script vous propose 4 choix simples :
* **Choix 1 (Cookies)** : Récupère vos cookies depuis Firefox. *(Attention : Firefox doit être fermé pendant cette étape).*
* **Choix 2 (Préparer)** : Analyse vos liens Spotify et prépare la liste des morceaux à télécharger en enlevant les doublons.
* **Choix 3 (Télécharger)** : Cherche et télécharge les musiques manquantes directement dans `~/Musique/`.
* **Choix 4 (Tout faire)** : Fait les étapes 1, 2 et 3 à la suite.

**À savoir :** Si certains morceaux sont introuvables ou bloqués, le script créera un fichier `Manquants.txt` dans le dossier `~/Musique/Script_Musique/` pour vous indiquer ce qu'il n'a pas réussi à télécharger.

---

# 🇬🇧 English Version

# 🎵 Music Downloader (Spotify to MP3)

## 📌 Project Context
This script was initially created to meet my own personal needs. It is a Bash script designed to run on **Linux**. It automatically downloads music from Spotify links (artists or playlists) in MP3 format by searching for tracks on YouTube and SoundCloud, and then adding the correct tags (title, artist, album). The music is neatly organized in your `~/Musique/` folder.

*🚀 **Coming soon:** I plan to adapt it into a Python program in the future to make it compatible with Windows and other operating systems.*

## Table of Contents
- [Step 1 : Dependencies to install](#step-1--dependencies-to-install)
- [Step 2 : Artist / Playlist list (How it works)](#step-2--artist--playlist-list-how-it-works)
- [Step 3 : Running the script](#step-3--running-the-script)

## Step 1 : Dependencies to install

To make the script work, you need a few tools and the **Firefox** browser (used to extract cookies to avoid being blocked by YouTube).

**1. Install system packages (example for Debian/Ubuntu/Mint):**
```bash
sudo apt update
sudo apt install ffmpeg jq gawk python3-pip
```

**2. Install download tools (via Python):**
```bash
pip3 install yt-dlp spotdl
```

*(Note: Make sure Firefox is installed on your machine).*

## Step 2 : Artist / Playlist list (How it works)

The script relies on a file named `Artiste.json`. 

**Where is this file?** 
It is located in `~/Musique/Script_Musique/Artiste.json`. 
*(Tip: If the folder or file doesn't exist, run the script once, and it will create them automatically).*

**How to fill it?**
Open the `Artiste.json` file with a text editor and add your Spotify links (artist or playlist links) as a JSON list. 

Here is the exact format to follow:

```json
[
  "https://open.spotify.com/artist/4Z8W4fZZB5yRxXI2PEYkEX",
  "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
]
```
*(Make sure to include the quotes and commas, except for the last line).*

## Step 3 : Running the script

**1. Make the script executable (only needed once):**
Open a terminal where your script is located and type:
```bash
chmod +x Music.sh
```

**2. Run the script:**
```bash
./Music.sh
```

**3. Use the menu:**
Once launched, the script offers 4 simple choices:
* **Choice 1 (Cookies)**: Extracts your cookies from Firefox. *(Warning: Firefox must be closed during this step).*
* **Choice 2 (Prepare)**: Analyzes your Spotify links and prepares the list of tracks to download by removing duplicates.
* **Choice 3 (Download)**: Searches for and downloads the missing music directly to `~/Musique/`.
* **Choice 4 (Do everything)**: Runs steps 1, 2, and 3 in a row.

**Good to know:** If some tracks cannot be found or are blocked, the script will create a `Manquants.txt` file in the `~/Musique/Script_Musique/` folder to show you what it failed to download.