#!/bin/bash

#Variable

CHEMIN="$HOME/Musique"            # où vont les musiques
SCRIPT="$CHEMIN/Script_Musique"   # où vivent le script et ses fichiers de travail
VAR_ARTISTE="$SCRIPT/Artiste.json"
OUTILS="yt-dlp spotdl ffmpeg jq awk"
# Pauses pour éviter que YouTube bloque la session pendant une heure
PAUSE_MORCEAU=10
PAUSE_RECHERCHE=3
TMP="$SCRIPT/tmp"
# Les listes de morceaux : elles sont longues à obtenir, on les garde (pas dans tmp)
LISTES="$SCRIPT/listes"
VAR_COOKIES="$TMP/cookies.txt"
# Une vraie tabulation : yt-dlp n'interprète pas « \t » dans --print
TAB=$'\t'
# Les morceaux que le script n'a pas su trouver, pour les chercher à la main
VAR_MANQUANTS="$SCRIPT/Manquants.txt"
# Vidéo quelconque, juste pour tester que les cookies marchent (on ne la télécharge pas)
VIDEO_TEST="https://www.youtube.com/watch?v=sNULh1Ew-S4"

# ---------- Petites fonctions de texte ----------

# Enlève les caractères qui ne peuvent pas figurer dans un nom de fichier (le « / »
# créerait un sous-dossier !) et resserre les espaces. Résultat dans PROPRE.
# « Protect The Land / Genocidal Humanoidz » -> « Protect The Land Genocidal Humanoidz »
propre () {
  local s="${1//[\/*<>:\"|?\\]/}"
  while [[ "$s" == *"  "* ]]; do s="${s//  / }"; done   # tant qu'il reste un espace double
  s="${s# }"; s="${s% }"
  PROPRE="$s"
}

# Met un texte en minuscules sans espaces ni ponctuation, dans la variable NORM.
# « 004 », « SAVE 003 » et « save003 » deviennent comparables.
# [:alnum:] garde les lettres de TOUS les alphabets : sans lui, « Луна » devenait vide.
norm () { local s="${1,,}"; NORM="${s//[^[:alnum:]]/}"; }

# ---------- Les étapes du menu ----------

Vérification () {

  # 1) Les outils : si l'un manque, on arrête tout de suite
  for OUTIL in $OUTILS; do
    command -v "$OUTIL" >/dev/null || { echo "Outil manquant : $OUTIL" >&2; exit 1; }
  done

  # 2) Les dossiers de travail (mkdir -p ne dit rien s'ils existent déjà)
  mkdir -p "$TMP" "$LISTES"

  # 3) La liste d'artistes : créée vide (« [] », une liste JSON vide) si elle n'existe pas
  [ -f "$VAR_ARTISTE" ] || { echo "[]" > "$VAR_ARTISTE"; echo "Fichier créé : $VAR_ARTISTE"; }

  echo "Vérification : tout est prêt."

}

Cookies () {

  # 1) Firefox doit être fermé : sinon il garde ses cookies pour lui et l'extraction échoue
  if pgrep -x firefox >/dev/null; then
    echo "Fermez d'abord Firefox puis réessayez."
    return 1
  fi

  # 2) yt-dlp lit les cookies dans Firefox et les écrit dans notre fichier.
  echo "Extraction des cookies depuis Firefox..."
  if yt-dlp --cookies-from-browser firefox --cookies "$VAR_COOKIES" --skip-download "$VIDEO_TEST" 2>&1 | grep -q "no longer valid"; then
    echo "Session YouTube expirée : reconnectez-vous à YouTube dans Firefox,"
    echo "fermez-le, puis relancez."
    return 1
  fi

  # 3) Ce fichier est un mot de passe déguisé : personne d'autre ne doit pouvoir le lire
  chmod 600 "$VAR_COOKIES"
  echo "Cookies enregistrés dans $VAR_COOKIES"

}

Artiste () {

  # mapfile range chaque lien du JSON dans un tableau. « < <(...) » évite le tuyau « | »,
  # qui ferait travailler bash dans un coin à part où nos variables seraient perdues.
  mapfile -t LIENS < <(jq -r '.[]' "$VAR_ARTISTE")

  # 1. Vérification avec syntaxe arithmétique et court-circuit
  (( ${#LIENS[@]} == 0 )) && { echo "Erreur : Aucun artiste dans $VAR_ARTISTE" >&2; return 1; }

  for LIEN in "${LIENS[@]}"; do
    echo "==> $LIEN"

    # 2. Exécution de spotdl (on efface d'abord : sinon, en cas d'échec, on retravaillerait
    #    sur la liste de l'artiste précédent sans le voir)
    rm -f "$TMP/brut.spotdl"
    spotdl save "$LIEN" --save-file "$TMP/brut.spotdl" </dev/null

    # 3. Vérification immédiate avec court-circuit au lieu du "if ! ..."
    jq -e 'length > 0' "$TMP/brut.spotdl" >/dev/null 2>&1 || {
      echo "   Échec pour cet artiste, réessayez plus tard." >&2
      continue
    }

    # 4. Le nom de l'artiste : Spotify le donne dans « list_name » (le nom de la page demandée).
    #    tr remplace les « / » par des « - », sinon « AC/DC » créerait un sous-dossier.
    NOM="$(jq -r '.[0].list_name' "$TMP/brut.spotdl" | tr '/' '-')"

    # 5. Doublons : on ne garde qu'une version par titre. On préfère l'originale
    #    (pas « Live », « Remix »...), un vrai album plutôt qu'un single, et
    #    l'édition normale plutôt que « Deluxe ». $V = la liste des variantes.
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

    # 6. Résumé à l'écran : le nombre de morceaux gardés, album par album
    jq -r --arg N "$NOM" '"   \($N) : \(length) morceaux uniques", (group_by(.album_name)[]
            | "     \(.[0].album_name)  (\(length) morceaux)")' "$LISTES/$NOM.spotdl"
  done

  # Ménage : on efface le fichier de travail, mais PAS les cookies (ils servent longtemps
  # et il faut fermer Firefox pour les refaire).
  rm -f "$TMP/brut.spotdl"

}

Télécharger () {

  # On repart d'un fichier de manquants vide : il est réécrit à chaque téléchargement
  : > "$VAR_MANQUANTS"

  # Cookies YouTube, seulement s'ils existent (certaines vidéos sont interdites aux mineurs)
  COOKIES_YT=()
  [ -f "$VAR_COOKIES" ] && COOKIES_YT=(--cookies "$VAR_COOKIES")

  # Liste de TOUS les titres déjà sur le disque, sans se fier au nom des dossiers :
  # un morceau rangé ailleurs ou nommé autrement est reconnu quand même.
  declare -A DEJA_LA
  while IFS= read -r -d '' F; do
    B="${F##*/}"; B="${B%.mp3}"
    norm "${B#* - }"
    [ -n "$NORM" ] && DEJA_LA["$NORM"]=1
  done < <(find "$CHEMIN" -name '*.mp3' -not -path "$SCRIPT/*" -print0)
  echo "${#DEJA_LA[@]} morceau(x) déjà sur le disque"

  for LISTE in "$LISTES"/*.spotdl; do
    [ -e "$LISTE" ] || { echo "Aucune liste dans $LISTES : faites le choix 2." >&2; return 1; }
    NOM="$(basename "$LISTE" .spotdl)"
    echo "==> $NOM"
    MANQUANTS=0

    while IFS=$'\t' read -r TITRE ARTISTE ALBUM; do

      # 1. Déjà sur le disque ? (comparaison sans majuscules ni ponctuation)
      norm "$TITRE"; CHERCHE="$NORM"
      [ -z "$CHERCHE" ] && CHERCHE="?"   # jamais d'indice vide : bash refuserait
      [ -n "${DEJA_LA[$CHERCHE]}" ] && continue

      # 2. Titre sans ce qui est entre parenthèses : Spotify écrit « (feat. Untel) »,
      #    YouTube presque jamais. On essaiera les deux écritures.
      COURT="$(sed -E 's/[[({][^])}]*[])}]//g; s/  +/ /g; s/^ +| +$//g' <<< "$TITRE")"

      # 3. Les recherches à essayer, dans l'ordre : YouTube puis SoundCloud (beaucoup de
      #    petits artistes n'ont que SoundCloud), avec le titre complet puis le titre court.
      RECHERCHES=("ytsearch5:$ARTISTE $TITRE")
      [ "$COURT" != "$TITRE" ] && RECHERCHES+=("ytsearch5:$ARTISTE $COURT")
      RECHERCHES+=("scsearch5:$ARTISTE $TITRE")
      [ "$COURT" != "$TITRE" ] && RECHERCHES+=("scsearch5:$ARTISTE $COURT")

      # 4. Le chemin du fichier, nettoyé des caractères interdits : sans ça,
      #    « Radio/Video » créerait un dossier « Radio » contenant « Video.mp3 ».
      propre "$ALBUM";             D_ALBUM="$PROPRE"
      propre "$ARTISTE - $TITRE";  F_NOM="$PROPRE"
      BASE="$CHEMIN/$NOM/$D_ALBUM/$F_NOM"   # sans extension
      FICHIER="$BASE.mp3"

      # 5. On cherche PUIS on télécharge, recherche après recherche. La condition d'arrêt
      #    est « le fichier existe », pas « j'ai trouvé une vidéo » : si toutes les vidéos
      #    d'une recherche échouent (interdites aux mineurs, supprimées, DRM...), on passe
      #    à la recherche suivante, donc à SoundCloud.
      EU_CANDIDAT=0
      for RECHERCHE in "${RECHERCHES[@]}"; do
        mapfile -t CANDIDATS < <(yt-dlp --flat-playlist --print "%(title)s${TAB}%(url)s" "$RECHERCHE" \
               </dev/null 2>/dev/null | awk -F'\t' -v t="$TITRE" -v t2="$COURT" -v a="$ARTISTE" '
                 function n(s) { s = tolower(s); gsub(/[^[:alnum:]]/, "", s); return s }
                 # mots ajoutés par la plateforme qui ne changent pas le morceau
                 function sansmots(v) { gsub(/official|music|videoclip|video|audio|lyrics|lyric|visualizer|hd|hq|4k/, "", v); return v }
                 function colle(v, T, A) {
                   if (T == "" || length(T) < 3) return 0
                   if (v == T || v == A T || v == T A) return 1
                   # le titre peut citer TOUS les artistes : « Skrillex, Boys Noize & Dylan Brady - ZEET NOISE »
                   if (index(v, A) == 1 && length(v) >= length(T) && substr(v, length(v) - length(T) + 1) == T) return 1
                   return 0
                 }
                 BEGIN { T = n(t); T2 = n(t2); A = n(a) }
                 {
                   v = n($1); w = sansmots(v)   # une seule fois, au lieu de quatre
                   if ((colle(v, T, A) || colle(w, T, A) || colle(v, T2, A) || colle(w, T2, A)) && !vu[$2]++)
                     print $2
                 }')
        sleep "$PAUSE_RECHERCHE"
        (( ${#CANDIDATS[@]} == 0 )) && continue
        (( EU_CANDIDAT )) || echo "   $TITRE"
        EU_CANDIDAT=1

        # On essaie jusqu'à 3 résultats de cette recherche
        for URL in "${CANDIDATS[@]:0:3}"; do
          yt-dlp -x --audio-format mp3 --embed-thumbnail \
            --sleep-interval "$PAUSE_MORCEAU" --max-sleep-interval $(( PAUSE_MORCEAU * 2 )) \
            "${COOKIES_YT[@]}" -o "$BASE.%(ext)s" \
            "$URL" </dev/null 2>&1 | grep -E "ERROR|rate-limited" >&2
          [ -f "$FICHIER" ] && break
        done
        [ -f "$FICHIER" ] && break
      done

      # 6. Résultat. Les étiquettes viennent de NOTRE liste : ffmpeg recopie le son tel quel
      #    (-c copy, donc sans perte ni attente) et ne réécrit que les étiquettes.
      if [ -f "$FICHIER" ]; then
        ffmpeg -loglevel error -y -i "$FICHIER" -map 0 -c copy \
          -metadata title="$TITRE" -metadata artist="$ARTISTE" -metadata album="$ALBUM" \
          "$FICHIER.part.mp3" && mv -f "$FICHIER.part.mp3" "$FICHIER"
        DEJA_LA["$CHERCHE"]=1
      else
        # « introuvable » = aucune plateforme n'avait le morceau ;
        # « échec » = des vidéos correspondaient mais toutes ont refusé (âge, DRM, supprimée)
        (( EU_CANDIDAT )) && RAISON="échec du téléchargement" || RAISON="introuvable"
        echo "   $RAISON : $TITRE  ($ALBUM)" >&2
        echo "$NOM$TAB$TITRE$TAB$ALBUM$TAB($RAISON)" >> "$VAR_MANQUANTS"
        MANQUANTS=$(( MANQUANTS + 1 ))
      fi

    done < <(jq -r '.[] | [.name, .artist, .album_name] | @tsv' "$LISTE")

    echo "   $NOM : $MANQUANTS morceau(x) introuvable(s)"
  done

  if [ -s "$VAR_MANQUANTS" ]; then
    echo "$(wc -l < "$VAR_MANQUANTS") morceau(x) à chercher à la main : $VAR_MANQUANTS"
  fi

}

Menu () {

  echo "1) Mettre à jour les cookies"
  echo "2) Préparer les artistes"
  echo "3) Télécharger"
  echo "4) Tout faire (1 + 2 + 3)"
  read -rp "Votre choix : " CHOIX

  # « case » = un aiguillage : selon ce qui a été tapé, on part dans une direction
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
