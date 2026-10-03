#!/bin/bash

# Activer les expressions régulières étendues de Bash (pour simplifier le nettoyage de texte)
shopt -s extglob

# Variables Globales
CHEMIN="$HOME/Musique"
SCRIPT="$CHEMIN/Script_Musique"
VAR_ARTISTE="$SCRIPT/Artiste.json"

# yt-dlp et spotdl sont installés dans le venv du projet : on le passe en premier dans le PATH
#export PATH="$SCRIPT/.venv/bin:$PATH"
OUTILS="yt-dlp spotdl ffmpeg jq awk"

PAUSE_MORCEAU=10
PAUSE_RECHERCHE=3
TMP="$SCRIPT/tmp"
LISTES="$SCRIPT/listes"
VAR_COOKIES="$TMP/cookies.txt"
VAR_MANQUANTS="$SCRIPT/Manquants.txt"
VIDEO_TEST="https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# ---------- Petites fonctions de texte ----------

# Enlève les caractères interdits et resserre les espaces (via extglob)
propre () {
  local s="${1//[\/*<>:\"|?\\]/}"
  s="${s//+( )/ }"        # Resserre les espaces multiples en un seul (grâce à extglob)
  s="${s# }"; s="${s% }"  # Enlève l'espace au début et à la fin
  PROPRE="$s"
}

# Met un texte en minuscules sans espaces ni ponctuation
norm () { 
  local s="${1,,}"
  NORM="${s//[^[:alnum:]]/}"
}

# ---------- Les étapes du menu ----------

Vérification () {
  local OUTIL
  # 1) Les outils
  for OUTIL in $OUTILS; do
    command -v "$OUTIL" >/dev/null || { echo "Outil manquant : $OUTIL" >&2; exit 1; }
  done

  # 2) Les dossiers de travail
  mkdir -p "$TMP" "$LISTES"

  # 3) La liste d'artistes
  [ -f "$VAR_ARTISTE" ] || { echo "[]" > "$VAR_ARTISTE"; echo "Fichier créé : $VAR_ARTISTE"; }
  echo "Vérification : tout est prêt."
}

Cookies () {
  # 1) Firefox doit être fermé
  if pgrep -x firefox >/dev/null; then
    echo "Fermez d'abord Firefox puis réessayez."
    return 1
  fi

  # 2) Extraction
  echo "Extraction des cookies depuis Firefox..."
  if yt-dlp --cookies-from-browser firefox --cookies "$VAR_COOKIES" --skip-download "$VIDEO_TEST" 2>&1 | grep -q "no longer valid"; then
    echo "Session YouTube expirée : reconnectez-vous à YouTube dans Firefox, fermez-le, puis relancez."
    return 1
  fi

  # 3) Sécurisation
  chmod 600 "$VAR_COOKIES"
  echo "Cookies enregistrés dans $VAR_COOKIES"
}

Artiste () {
  local -a LIENS
  local LIEN NOM

  mapfile -t LIENS < <(jq -r '.[]' "$VAR_ARTISTE")
  (( ${#LIENS[@]} == 0 )) && { echo "Erreur : Aucun artiste dans $VAR_ARTISTE" >&2; return 1; }

  for LIEN in "${LIENS[@]}"; do
    echo "==> $LIEN"
    rm -f "$TMP/brut.spotdl"
    
    spotdl save "$LIEN" --save-file "$TMP/brut.spotdl" </dev/null
    
    jq -e 'length > 0' "$TMP/brut.spotdl" >/dev/null 2>&1 || {
      echo "   Échec pour cet artiste, réessayez plus tard." >&2
      continue
    }

    NOM="$(jq -r '.[0].list_name' "$TMP/brut.spotdl" | tr '/' '-')"

    jq --arg V 'live|remaster|remix|edit|version|mix|demo|acoustic|instrumental|explicit' '
      def cle: ascii_downcase | gsub("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]"; "")
             | sub("\\s+-\\s+.*(" + $V + ").*$"; "");
      map(.cle = (.name | cle)
          | if (.cle | test("[a-z]")) then . else .cle += " | " + .album_name end)
      | group_by(.cle)
      | map(min_by([ (.name | test($V; "i")), (.tracks_count < 5),
                     (.album_name | test("[(\\[]")), -.tracks_count ]))
      | map({name, artist, album_name})
    ' "$TMP/brut.spotdl" > "$LISTES/$NOM.spotdl"

    jq -r --arg N "$NOM" '"   \($N) : \(length) morceaux uniques", (group_by(.album_name)[]
            | "     \(.[0].album_name)  (\(length) morceaux)")' "$LISTES/$NOM.spotdl"
  done

  rm -f "$TMP/brut.spotdl"
}

Télécharger () {
  local -a COOKIES_YT=()
  local F B LISTE NOM MANQUANTS TITRE ARTISTE ALBUM CHERCHE COURT D_ALBUM F_NOM BASE FICHIER EU_CANDIDAT RECHERCHE URL RAISON
  local -a RECHERCHES CANDIDATS

  : > "$VAR_MANQUANTS"
  [ -f "$VAR_COOKIES" ] && COOKIES_YT=(--cookies "$VAR_COOKIES")

  # Liste des titres existants
  declare -A DEJA_LA
  while IFS= read -r -d '' F; do
    B="${F##*/}"; B="${B%.mp3}"
    norm "${B#* - }"
    [ -n "$NORM" ] && DEJA_LA["$NORM"]=1
  done < <(find "$CHEMIN" -name '*.mp3' -not -path "$SCRIPT/*" -print0)
  echo "${#DEJA_LA[@]} morceau(x) déjà sur le disque"

  # Le script awk isolé pour plus de lisibilité
  local AWK_SCRIPT='
    function n(s) { s = tolower(s); gsub(/[^[:alnum:]]/, "", s); return s }
    function sansmots(v) { gsub(/official|music|videoclip|video|audio|lyrics|lyric|visualizer|hd|hq|4k/, "", v); return v }
    function colle(v, T, A) {
      if (T == "" || length(T) < 3) return 0
      if (v == T || v == A T || v == T A) return 1
      if (index(v, A) == 1 && length(v) >= length(T) && substr(v, length(v) - length(T) + 1) == T) return 1
      return 0
    }
    BEGIN { T = n(t); T2 = n(t2); A = n(a) }
    {
      v = n($1); w = sansmots(v)
      if ((colle(v, T, A) || colle(w, T, A) || colle(v, T2, A) || colle(w, T2, A)) && !vu[$2]++)
        print $2
    }
  '

  for LISTE in "$LISTES"/*.spotdl; do
    [ -e "$LISTE" ] || { echo "Aucune liste dans $LISTES : faites le choix 2." >&2; return 1; }
    NOM="$(basename "$LISTE" .spotdl)"
    echo "==> $NOM"
    MANQUANTS=0

    while IFS=$'\t' read -r TITRE ARTISTE ALBUM; do
      norm "$TITRE"; CHERCHE="${NORM:-?}"
      [ -n "${DEJA_LA[$CHERCHE]}" ] && continue

      # Titre sans parenthèses/crochets (plus rapide que sed en Bash natif)
      COURT="${TITRE//\(*\)/}"     # Enlève ce qui est entre ( )
      COURT="${COURT//\[*\]/}"     # Enlève ce qui est entre [ ]
      COURT="${COURT//\{*\}/}"     # Enlève ce qui est entre { }
      COURT="${COURT//+( )/ }"     # Resserre les espaces
      COURT="${COURT# }"; COURT="${COURT% }" # Trim

      RECHERCHES=("ytsearch5:$ARTISTE $TITRE")
      [ "$COURT" != "$TITRE" ] && RECHERCHES+=("ytsearch5:$ARTISTE $COURT")
      RECHERCHES+=("scsearch5:$ARTISTE $TITRE")
      [ "$COURT" != "$TITRE" ] && RECHERCHES+=("scsearch5:$ARTISTE $COURT")

      propre "$ALBUM";             D_ALBUM="$PROPRE"
      propre "$ARTISTE - $TITRE";  F_NOM="$PROPRE"
      BASE="$CHEMIN/$NOM/$D_ALBUM/$F_NOM"
      FICHIER="$BASE.mp3"

      EU_CANDIDAT=0
      for RECHERCHE in "${RECHERCHES[@]}"; do
        # Utilisation de la variable AWK_SCRIPT et injection de la tabulation pour yt-dlp
        mapfile -t CANDIDATS < <(yt-dlp --flat-playlist --print "%(title)s"$'\t'"%(url)s" "$RECHERCHE" \
               </dev/null 2>/dev/null | awk -F'\t' -v t="$TITRE" -v t2="$COURT" -v a="$ARTISTE" "$AWK_SCRIPT")
        
        sleep "$PAUSE_RECHERCHE"
        (( ${#CANDIDATS[@]} == 0 )) && continue
        (( EU_CANDIDAT )) || echo "   $TITRE"
        EU_CANDIDAT=1

        for URL in "${CANDIDATS[@]:0:3}"; do
          yt-dlp -x --audio-format mp3 --embed-thumbnail \
            --sleep-interval "$PAUSE_MORCEAU" --max-sleep-interval $(( PAUSE_MORCEAU * 2 )) \
            "${COOKIES_YT[@]}" -o "$BASE.%(ext)s" \
            "$URL" </dev/null 2>&1 | grep -E "ERROR|rate-limited" >&2
          [ -f "$FICHIER" ] && break
        done
        [ -f "$FICHIER" ] && break
      done

      if [ -f "$FICHIER" ]; then
        ffmpeg -loglevel error -y -i "$FICHIER" -map 0 -c copy \
          -metadata title="$TITRE" -metadata artist="$ARTISTE" -metadata album="$ALBUM" \
          "$FICHIER.part.mp3" && mv -f "$FICHIER.part.mp3" "$FICHIER"
        DEJA_LA["$CHERCHE"]=1
      else
        (( EU_CANDIDAT )) && RAISON="échec du téléchargement" || RAISON="introuvable"
        echo "   $RAISON : $TITRE  ($ALBUM)" >&2
        
        # Utilisation de printf pour écrire dans le fichier avec des tabulations propres
        printf "%s\t%s\t%s\t(%s)\n" "$NOM" "$TITRE" "$ALBUM" "$RAISON" >> "$VAR_MANQUANTS"
        
        (( MANQUANTS++ ))
      fi

    done < <(jq -r '.[] | [.name, .artist, .album_name] | @tsv' "$LISTE")

    echo "   $NOM : $MANQUANTS morceau(x) introuvable(s)"
  done

  if [ -s "$VAR_MANQUANTS" ]; then
    echo "$(wc -l < "$VAR_MANQUANTS") morceau(x) à chercher à la main : $VAR_MANQUANTS"
  fi
}

Menu () {
  local CHOIX
  echo "1) Mettre à jour les cookies"
  echo "2) Préparer les artistes"
  echo "3) Télécharger"
  echo "4) Tout faire (1 + 2 + 3)"
  read -rp "Votre choix : " CHOIX

  case "$CHOIX" in
    1) Cookies ;;
    2) Artiste ;;
    3) Télécharger ;;
    4) Cookies && Artiste && Télécharger ;;
    *) echo "Choix invalide." ;;
  esac
}

Vérification
Menu