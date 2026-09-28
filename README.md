# antrop-setup

Gör en Mac redo för Antrops verktyg: git, GitHub CLI, inloggning på GitHub och, om man vill, Node, uv och Antrops Claude-plugins. Ett och samma skript för alla mallar, så att det bara finns ett ställe att rätta.

Repot är publikt eftersom skriptet körs innan datorn är inloggad på GitHub. Lägg aldrig nycklar eller annat hemligt här.

## Köra

```bash
curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh | bash
```

Med val, till exempel för Keynote-skillen (verktyg, medlemskap i antrop-ab och pluginet antrop-toolbox):

```bash
curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh | bash -s -- --org antrop-ab --plugins antrop-toolbox
```

Claude kan också köra skriptet åt den som inte är van vid terminalen. Utan terminal frågar det ingenting, och inloggningen på GitHub skriver ut en engångskod som man klistrar in på github.com/login/device.

| Val | Gör |
|---|---|
| `--title <text>` | rubriken överst (standard: Antrops verktyg) |
| `--org <org>` | kräv medlemskap i GitHub-organisationen, till exempel `antrop-ab` |
| `--node` | installera Node (LTS) |
| `--uv` | installera uv, som ger Python |
| `--gh-scopes <scopes>` | extra behörighet vid GitHub-inloggningen, till exempel `workflow` |
| `--plugins <a,b>` | installera eller uppdatera plugins från Antrops marketplace (`antrop-ab/antrop-skills`); kräver `--org antrop-ab` |
| `--brew-default <j\|n>` | förvalt svar på frågan om Homebrew (standard: n) |
| `--no-brew` | hoppa över Homebrew |

Skriptet kan köras om hur många gånger som helst: det som redan är klart hoppas över, och plugins uppdateras.

## Vem använder det

Mallarnas egna `scripts/bootstrap.sh` hämtar och kör det här först och gör sedan sitt eget:

- [antrop-prototype-template](https://github.com/antrop-ab/antrop-prototype-template): `--node --org antrop-ab --gh-scopes workflow`, sedan prototyp och Vercel
- antrop-analys: `--uv`, sedan analysmapp och Kleer-nyckel
- sj-design-code-template: `--node`, sedan prototyp och Vercel

Ändrar du ett val här: sök efter `antrop-setup` i de repona.
