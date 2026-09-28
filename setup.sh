#!/usr/bin/env bash
# Gör en Mac redo för Antrops verktyg: git, GitHub CLI, inloggning på GitHub och, om man vill,
# Node, uv och Antrops Claude-plugins. Mallarnas egna bootstrap-skript kör det här först och
# gör sedan sitt eget (prototyp, analysmapp, ...).
#
#   curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh | bash -s -- --org antrop-ab --plugins antrop-toolbox
#
# Är användaren administratör erbjuds Homebrew först (lösenordet behövs en gång). Annars hamnar
# verktygen i ~/.local, utan lösenord. Skriptet kan köras om hur många gånger som helst: det som
# redan är klart hoppas över, och Claude-plugins uppdateras. Det användaren själv gör:
#   - skriver sitt datorlösenord för Homebrew, eller klickar Installera i rutan för Apples
#     utvecklarverktyg (ger git) om Homebrew hoppas över
#   - godkänner GitHub i webbläsaren
#
# Val (skrivs efter `| bash -s --`):
#   --title <text>        rubriken överst (standard: Antrops verktyg)
#   --org <org>           kräv medlemskap i GitHub-organisationen, till exempel antrop-ab
#   --node                installera Node (LTS)
#   --uv                  installera uv (ger Python)
#   --gh-scopes <scopes>  extra behörigheter vid inloggningen på GitHub, till exempel workflow
#   --plugins <a,b>       installera eller uppdatera Antrops Claude-plugins (kräver --org antrop-ab)
#   --brew-default <j|n>  förvalt svar på frågan om Homebrew (standard: n)
#   --no-brew             hoppa över Homebrew
#
# Körs skriptet utan terminal (till exempel av en kodagent) frågar det ingenting. Inloggningen på
# GitHub skriver då ut en engångskod som användaren klistrar in i webbläsaren.

set -uo pipefail

MARKETPLACE="antrop-ab/antrop-skills"
MARKETPLACE_NAME="antrop"
BIN="$HOME/.local/bin"
NODE_DIR="$HOME/.local/node"
PROFILE_MARK="# Antrops setup: verktyg i ~/.local"

TITLE="Antrops verktyg"
ORG=""
WANT_NODE=0
WANT_UV=0
GH_SCOPES=""
PLUGINS=""
BREW_WANTED="ask"
BREW_DEFAULT="n"
PROFILE_CHANGED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="${2:-}"; shift 2 ;;
    --org) ORG="${2:-}"; shift 2 ;;
    --node) WANT_NODE=1; shift ;;
    --uv) WANT_UV=1; shift ;;
    --gh-scopes) GH_SCOPES="${2:-}"; shift 2 ;;
    --plugins) PLUGINS="${2:-}"; shift 2 ;;
    --brew-default) BREW_DEFAULT="${2:-n}"; shift 2 ;;
    --no-brew) BREW_WANTED="no"; shift ;;
    *) printf 'Okänt val: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ -t 1 ]; then B=$'\033[1m'; R=$'\033[0m'; else B=""; R=""; fi
STEP=0
STEPS=$((4 + WANT_NODE + WANT_UV + $([ -n "$PLUGINS" ] && echo 1 || echo 0)))
step() { STEP=$((STEP + 1)); printf '\n%s==> %s/%s %s%s\n' "$B" "$STEP" "$STEPS" "$1" "$R"; }
ok() { printf '    Klart: %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
fail() {
  printf '\n%sStopp:%s %s\n' "$B" "$R" "$1" >&2
  [ -n "${2:-}" ] && printf '       %s\n' "$2" >&2
  exit 1
}

# /dev/tty finns även när skriptet kommer via `curl | bash`, men inte när en kodagent kör det.
if ( : </dev/tty ) 2>/dev/null; then HAS_TTY=1; else HAS_TTY=0; fi
ask() {
  local answer=""
  if [ "$HAS_TTY" = 1 ]; then
    printf '    %s ' "$1" >/dev/tty
    read -r answer </dev/tty || true
  fi
  printf '%s' "${answer:-$2}"
}
yes_answer() { case "$1" in j|J|ja|Ja|y|Y|yes) return 0 ;; *) return 1 ;; esac; }

# Gamla eller felaktiga tokens och andra GitHub-värdar (GitHub Enterprise) går annars före
# inloggningen på github.com. Gäller bara det här skriptet.
unset GH_HOST GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN

[ "$(uname -s)" = "Darwin" ] || fail "Skriptet är gjort för Mac."
if [ -n "$PLUGINS" ] && [ "$ORG" != "antrop-ab" ]; then
  fail "--plugins kräver --org antrop-ab: Antrops marketplace är privat."
fi
# hw.optional.arm64 stämmer även om Terminal körs via Rosetta.
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then
  NODE_ARCH="arm64"; GH_ARCH="arm64"; UV_ARCH="aarch64"
else
  NODE_ARCH="x64"; GH_ARCH="amd64"; UV_ARCH="x86_64"
fi

mkdir -p "$BIN"
export PATH="$BIN:$NODE_DIR/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf '%s%s: sätter upp din dator%s\n' "$B" "$TITLE" "$R"
info "Du kan köra det här igen när som helst. Det som redan är klart hoppas över."

# Laddar ner en fil och kontrollerar den mot kontrollsumman. Summafilen kan ha en rad per fil
# ("<summa>  <fil>") eller bara en summa.
download_verified() { # url summa-url filnamn
  curl -fsSL "$1" -o "$TMP/$3" && curl -fsSL "$2" -o "$TMP/sums.txt" || return 1
  local want got
  want="$(grep -E "[ *]$3\$" "$TMP/sums.txt" | awk '{print $1}')"
  [ -n "$want" ] || want="$(awk 'NR==1{print $1}' "$TMP/sums.txt")"
  got="$(shasum -a 256 "$TMP/$3" | awk '{print $1}')"
  [ -n "$want" ] && [ "$want" = "$got" ]
}

# Homebrew ---------------------------------------------------------------------

step "Homebrew (valfritt)"
brew_path() {
  local p
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}
BREW=""
if BREW="$(brew_path)"; then
  eval "$("$BREW" shellenv)"
  ok "$("$BREW" --version | head -1)"
elif [ "$BREW_WANTED" = "no" ]; then
  info "Hoppade över."
elif ! id -Gn | tr ' ' '\n' | grep -qx admin; then
  info "Ditt konto är inte administratör, så Homebrew går inte att installera. Det gör inget,"
  info "resten fungerar utan. Vill du ha Homebrew senare: fråga IT."
elif [ "$HAS_TTY" = 0 ]; then
  info "Homebrew behöver ditt datorlösenord och kan bara installeras från Terminal. Hoppar över."
else
  info "Homebrew är en app store för utvecklarverktyg. Med den kan Claude senare installera"
  info "fler verktyg åt dig utan att fråga efter lösenord. Allt här fungerar utan."
  if yes_answer "$BREW_DEFAULT"; then choices="[J/n]"; else choices="[j/N]"; fi
  if yes_answer "$(ask "Installera Homebrew? Det kräver ditt datorlösenord en gång. $choices:" "$BREW_DEFAULT")"; then
    info "Skriv ditt datorlösenord och tryck Enter. Det syns inte medan du skriver."
    sudo -v </dev/tty || fail "Lösenordet godkändes inte." "Kör skriptet igen, eller lägg till --no-brew."
    info "Installerar Homebrew. Saknas Apples utvecklarverktyg hämtas de också, det kan ta 10 till 20 minuter."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null \
      || fail "Homebrew-installationen misslyckades." "Kör skriptet igen, eller lägg till --no-brew."
    BREW="$(brew_path)" || fail "Homebrew installerades men hittas inte."
    eval "$("$BREW" shellenv)"
    ok "$("$BREW" --version | head -1)"
  else
    info "Hoppade över. Kör skriptet igen om du ändrar dig."
  fi
fi

# Vanligaste Homebrew-felet: raderna i ~/.zprofile kördes aldrig, så Terminal hittar inte brew.
if [ -n "$BREW" ] && ! grep -qF "$BREW shellenv" "$HOME/.zprofile" 2>/dev/null; then
  printf '\neval "$(%s shellenv)"\n' "$BREW" >>"$HOME/.zprofile"
  PROFILE_CHANGED=1
fi

# Git --------------------------------------------------------------------------

step "Git"
# Utan utvecklarverktyg är /usr/bin/git bara en platshållare. Kör den inte innan verktygen
# finns, den öppnar i så fall installationsrutan på egen hand.
git_works() { git --version >/dev/null 2>&1; }
if xcode-select -p >/dev/null 2>&1 || { gitpath="$(command -v git)" && [ "$gitpath" != "/usr/bin/git" ]; }; then
  if ! git_works; then
    if git --version 2>&1 | grep -qi license; then
      fail "Xcode är installerat men licensen är inte godkänd, så git fungerar inte." \
        "Öppna Xcode en gång och godkänn licensen (eller be IT), och kör sedan skriptet igen."
    fi
    fail "Git finns men fungerar inte: $(git --version 2>&1 | head -1)" "Be Claude eller IT om hjälp."
  fi
  ok "$(git --version)"
else
  info "Git följer med Apples utvecklarverktyg (Command Line Tools)."
  info "En ruta öppnas nu. Klicka Installera och vänta, det tar 5 till 15 minuter."
  info "Frågar rutan efter ett administratörslösenord som du inte har: be IT installera"
  info "Command Line Tools, och kör sedan skriptet igen."
  xcode-select --install >/dev/null 2>&1 || true
  waited=0
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
    waited=$((waited + 10))
    [ "$waited" -ge 3600 ] && fail "Utvecklarverktygen blev inte klara inom en timme." "Kör skriptet igen när installationen är klar."
  done
  git_works || fail "Utvecklarverktygen är installerade men git svarar inte." "Kör skriptet igen, eller be Claude om hjälp."
  ok "$(git --version)"
fi

# Node (valfritt) --------------------------------------------------------------

if [ "$WANT_NODE" = 1 ]; then
  step "Node.js"
  node_major() { node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }
  if [ "$(node_major)" -ge 20 ]; then
    ok "Node $(node --version)"
  elif [ -n "$BREW" ]; then
    info "Installerar Node med Homebrew"
    "$BREW" install node >/dev/null || fail "Homebrew kunde inte installera Node." "Kör skriptet igen."
    hash -r
    ok "Node $(node --version)"
  else
    # Senaste LTS-versionen: första raden i listan som har ett LTS-namn.
    curl -fsSL https://nodejs.org/dist/index.json -o "$TMP/index.json" \
      || fail "Kunde inte hämta Nodes versionslista." "Kolla internetuppkopplingen och kör skriptet igen."
    version="$(grep '"lts":"' "$TMP/index.json" | head -1 | sed -E 's/.*"version":"(v[0-9.]+)".*/\1/')"
    [ -n "$version" ] || fail "Kunde inte hämta Nodes versionslista." "Kolla internetuppkopplingen och kör skriptet igen."
    file="node-$version-darwin-$NODE_ARCH.tar.gz"
    info "Hämtar Node $version till ~/.local/node"
    download_verified "https://nodejs.org/dist/$version/$file" "https://nodejs.org/dist/$version/SHASUMS256.txt" "$file" \
      || fail "Nedladdningen av Node misslyckades eller blev fel." "Kör skriptet igen."
    mkdir -p "$TMP/node"
    tar -xzf "$TMP/$file" -C "$TMP/node" --strip-components 1 || fail "Kunde inte packa upp Node."
    rm -rf "$NODE_DIR" && mv "$TMP/node" "$NODE_DIR"
    hash -r
    ok "Node $(node --version)"
  fi
fi

# uv (valfritt) ----------------------------------------------------------------

if [ "$WANT_UV" = 1 ]; then
  step "uv (ger Python)"
  if command -v uv >/dev/null 2>&1; then
    ok "$(uv --version)"
  elif [ -n "$BREW" ]; then
    info "Installerar uv med Homebrew"
    "$BREW" install uv >/dev/null || fail "Homebrew kunde inte installera uv." "Kör skriptet igen."
    hash -r
    ok "$(uv --version)"
  else
    asset="uv-${UV_ARCH}-apple-darwin.tar.gz"
    base="https://github.com/astral-sh/uv/releases/latest/download"
    info "Hämtar uv till ~/.local/bin"
    download_verified "$base/$asset" "$base/$asset.sha256" "$asset" \
      || fail "Nedladdningen av uv misslyckades eller blev fel." "Kör skriptet igen."
    tar -xzf "$TMP/$asset" -C "$TMP" || fail "Kunde inte packa upp uv."
    cp "$TMP/uv-${UV_ARCH}-apple-darwin/uv" "$TMP/uv-${UV_ARCH}-apple-darwin/uvx" "$BIN/" && chmod +x "$BIN/uv" "$BIN/uvx"
    hash -r
    ok "$(uv --version)"
  fi
fi

# GitHub CLI -------------------------------------------------------------------

step "GitHub CLI"
if command -v gh >/dev/null 2>&1; then
  ok "$(gh --version | head -1)"
elif [ -n "$BREW" ]; then
  info "Installerar GitHub CLI med Homebrew"
  "$BREW" install gh >/dev/null || fail "Homebrew kunde inte installera GitHub CLI." "Kör skriptet igen."
  hash -r
  ok "$(gh --version | head -1)"
else
  # Adressen till senaste versionen slutar på /tag/vX.Y.Z. Undviker GitHubs API-gräns.
  latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest)"
  ver="${latest##*/v}"
  [ -n "$ver" ] && [ "$ver" != "$latest" ] || fail "Kunde inte hitta senaste versionen av GitHub CLI." "Kolla internetuppkopplingen och kör skriptet igen."
  zip="gh_${ver}_macOS_${GH_ARCH}.zip"
  base="https://github.com/cli/cli/releases/download/v$ver"
  info "Hämtar GitHub CLI $ver till ~/.local/bin"
  download_verified "$base/$zip" "$base/gh_${ver}_checksums.txt" "$zip" \
    || fail "Nedladdningen av GitHub CLI misslyckades eller blev fel." "Kör skriptet igen."
  unzip -q -o "$TMP/$zip" -d "$TMP" || fail "Kunde inte packa upp GitHub CLI."
  cp "$TMP/gh_${ver}_macOS_${GH_ARCH}/bin/gh" "$BIN/gh" && chmod +x "$BIN/gh"
  hash -r
  ok "$(gh --version | head -1)"
fi

# Terminal och kodagenten ska hitta det som hamnat i ~/.local även i nästa fönster.
if [ -n "$(ls -A "$BIN" 2>/dev/null)" ] || [ -x "$NODE_DIR/bin/node" ]; then
  for profile in "$HOME/.zprofile" "$HOME/.bash_profile"; do
    [ "$profile" = "$HOME/.bash_profile" ] && [ ! -f "$profile" ] && continue
    if ! grep -qF "$PROFILE_MARK" "$profile" 2>/dev/null; then
      printf '\n%s\nexport PATH="$HOME/.local/bin:$HOME/.local/node/bin:$PATH"\n' "$PROFILE_MARK" >>"$profile"
      PROFILE_CHANGED=1
    fi
  done
fi

# Logga in på GitHub -----------------------------------------------------------

step "Logga in på GitHub"
scopes=()
[ -n "$GH_SCOPES" ] && scopes=(--scopes "$GH_SCOPES")
if gh auth status --hostname github.com >/dev/null 2>&1; then
  ok "Inloggad som $(gh api user --jq .login)"
  # En inloggning utan behörigheten som mallen behöver: be om den i efterhand.
  if [ -n "$GH_SCOPES" ] && ! gh auth status --hostname github.com 2>&1 | grep -q "$GH_SCOPES"; then
    info "GitHub behöver också behörigheten $GH_SCOPES. Klistra in koden som visas och klicka Authorize."
    if [ "$HAS_TTY" = 1 ]; then
      gh auth refresh --hostname github.com --scopes "$GH_SCOPES" </dev/tty || info "Behörigheten lades inte till. Kör skriptet igen."
    else
      open "https://github.com/login/device" >/dev/null 2>&1 || true
      gh auth refresh --hostname github.com --scopes "$GH_SCOPES" </dev/null || info "Behörigheten lades inte till. Kör skriptet igen."
    fi
  fi
else
  if [ -n "$ORG" ]; then
    info "Du behöver ett GitHub-konto som är medlem i $ORG. Har du inget konto: skapa ett gratis"
    info "på https://github.com/signup och be någon på Antrop bjuda in dig."
  else
    info "Du behöver ett GitHub-konto. Det är gratis: https://github.com/signup"
    info "(skapa det först om du inte har något)."
  fi
  info ""
  info "Nu öppnas webbläsaren. Klistra in koden som visas nedanför och klicka Authorize."
  if [ "$HAS_TTY" = 1 ]; then
    gh auth login --hostname github.com --git-protocol https --web ${scopes[@]+"${scopes[@]}"} </dev/tty
  else
    # Utan terminal öppnar gh inte webbläsaren själv.
    open "https://github.com/login/device" >/dev/null 2>&1 || true
    gh auth login --hostname github.com --git-protocol https --web ${scopes[@]+"${scopes[@]}"} </dev/null
  fi
  gh auth status --hostname github.com >/dev/null 2>&1 || fail "Inloggningen på GitHub blev inte klar." "Kör skriptet igen."
  ok "Inloggad som $(gh api user --jq .login)"
fi
gh auth setup-git --hostname github.com >/dev/null 2>&1 || true

if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
  # GitHubs noreply-adress, så att den privata mejladressen inte hamnar i historiken.
  gh_name="$(gh api user --jq '.name // .login')"
  gh_email="$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
  [ -n "$(git config --global user.name)" ] || git config --global user.name "$gh_name"
  [ -n "$(git config --global user.email)" ] || git config --global user.email "$gh_email"
fi
ok "Git sparar dina ändringar som $(git config --global user.name) <$(git config --global user.email)>"

if [ -n "$ORG" ]; then
  [ "$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)" = "active" ] \
    || fail "Ditt GitHub-konto är inte medlem i $ORG ännu." \
      "Be någon på Antrop bjuda in $(gh api user --jq .login) till https://github.com/$ORG, godkänn inbjudan i mejlet och kör skriptet igen."
  ok "Medlem i $ORG"
fi

# Claude-plugins (valfritt) ----------------------------------------------------

if [ -n "$PLUGINS" ]; then
  step "Antrops Claude-plugins"
  # Claude-appen har ett eget claude-kommando. Finns inget i PATH används appens.
  CLAUDE="$(command -v claude || true)"
  if [ -z "$CLAUDE" ]; then
    CLAUDE="$(ls -d "$HOME/Library/Application Support/Claude/claude-code/"*/claude.app/Contents/MacOS/claude 2>/dev/null \
      | sort -V | tail -1)"
  fi
  if [ -z "$CLAUDE" ] || [ ! -x "$CLAUDE" ]; then
    info "Hittade inte Claude. Installera Claude-appen (https://claude.ai/download), öppna den en gång"
    info "och kör skriptet igen."
  else
    "$CLAUDE" plugin marketplace add "$MARKETPLACE" </dev/null >/dev/null 2>&1 \
      || fail "Kunde inte lägga till Antrops marketplace." "Kör skriptet igen, eller be Claude om hjälp."
    "$CLAUDE" plugin marketplace update "$MARKETPLACE_NAME" </dev/null >/dev/null 2>&1 || true
    IFS=',' read -r -a plugin_list <<<"$PLUGINS"
    for plugin in "${plugin_list[@]}"; do
      plugin="${plugin// /}"
      [ -n "$plugin" ] || continue
      id="$plugin@$MARKETPLACE_NAME"
      "$CLAUDE" plugin install "$id" </dev/null >/dev/null 2>&1 \
        || fail "Kunde inte installera $id." "Stämmer namnet? Kör skriptet igen, eller be Claude om hjälp."
      "$CLAUDE" plugin update "$id" </dev/null >/dev/null 2>&1 || true
      version="$("$CLAUDE" plugin list --json 2>/dev/null | grep -A2 "\"id\": \"$id\"" | sed -nE 's/.*"version": "([^"]+)".*/\1/p' | head -1)"
      ok "$id ${version:+$version}"
    done
    info "Starta en ny session i Claude-appen så att pluginen laddas."
  fi
fi

# Klart ------------------------------------------------------------------------

printf '\n%s==> Verktygen är klara%s\n' "$B" "$R"
[ "$PROFILE_CHANGED" = 1 ] && info "Öppna ett nytt Terminal-fönster om du vill använda verktygen i Terminal."
exit 0
